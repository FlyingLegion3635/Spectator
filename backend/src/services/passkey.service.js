const { FieldValue } = require('firebase-admin/firestore');
const {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} = require('@simplewebauthn/server');
const { db } = require('../config/firebase');
const { env } = require('../config/env');
const { COLLECTIONS } = require('../constants/collections');
const { ApiError } = require('../utils/apiError');
const { serializeDoc } = require('../utils/serialize');
const { buildAuthPayload } = require('./auth.service');

const passkeyChallenges = new Map();

function assertPasskeysEnabled() {
  if (!env.ENABLE_PASSKEYS) {
    throw new ApiError(403, 'Passkeys are disabled by server configuration');
  }
}

function usernameToKey(username) {
  return username.trim().toLowerCase();
}

function saveChallenge(key, challenge, type, userId) {
  passkeyChallenges.set(key, {
    challenge,
    type,
    userId,
    expiresAt: Date.now() + 5 * 60 * 1000,
  });
}

function consumeChallenge(key, type) {
  const challenge = passkeyChallenges.get(key);
  passkeyChallenges.delete(key);

  if (!challenge || challenge.type !== type || challenge.expiresAt < Date.now()) {
    throw new ApiError(400, 'Passkey challenge expired. Retry the passkey flow.');
  }

  return challenge;
}

async function getUserByUsername(username) {
  const usernameNormalized = usernameToKey(username);

  const query = await db
    .collection(COLLECTIONS.USERS)
    .where('usernameNormalized', '==', usernameNormalized)
    .limit(1)
    .get();

  if (query.empty) {
    throw new ApiError(404, 'User not found for passkey login');
  }

  const doc = query.docs[0];
  const user = serializeDoc(doc);
  return { user, docRef: doc.ref };
}

async function getUserById(userId) {
  const snap = await db.collection(COLLECTIONS.USERS).doc(userId).get();

  if (!snap.exists) {
    throw new ApiError(404, 'User not found');
  }

  return { user: serializeDoc(snap), docRef: snap.ref };
}

function toStoredPasskey(passkey) {
  return {
    id: passkey.id,
    publicKeyBase64: Buffer.from(passkey.publicKey).toString('base64'),
    counter: passkey.counter,
    transports: passkey.transports || [],
    deviceType: passkey.deviceType || 'singleDevice',
    backedUp: Boolean(passkey.backedUp),
    createdAt: new Date().toISOString(),
  };
}

function passkeyToAuthenticator(passkey) {
  return {
    id: passkey.id,
    publicKey: Buffer.from(passkey.publicKeyBase64, 'base64'),
    counter: Number(passkey.counter || 0),
    transports: Array.isArray(passkey.transports) ? passkey.transports : [],
  };
}

async function getRegistrationOptionsForUser(userId) {
  assertPasskeysEnabled();

  const { user } = await getUserById(userId);
  const passkeys = Array.isArray(user.passkeys) ? user.passkeys : [];

  const options = await generateRegistrationOptions({
    rpName: env.PASSKEY_RP_NAME,
    rpID: env.PASSKEY_RP_ID,
    userName: user.username,
    userID: user.id,
    timeout: 60000,
    attestationType: 'none',
    excludeCredentials: passkeys.map((passkey) => ({
      id: passkey.id,
      type: 'public-key',
      transports: passkey.transports || [],
    })),
    authenticatorSelection: {
      residentKey: 'preferred',
      userVerification: 'preferred',
    },
  });

  saveChallenge(
    usernameToKey(user.username),
    options.challenge,
    'register',
    user.id,
  );

  return options;
}

async function verifyRegistrationForUser(userId, response) {
  assertPasskeysEnabled();

  const { user, docRef } = await getUserById(userId);
  const key = usernameToKey(user.username);
  const challenge = consumeChallenge(key, 'register');

  if (challenge.userId !== user.id) {
    throw new ApiError(400, 'Passkey challenge user mismatch');
  }

  const verification = await verifyRegistrationResponse({
    response,
    expectedChallenge: challenge.challenge,
    expectedOrigin: env.PASSKEY_RP_ORIGINS,
    expectedRPID: env.PASSKEY_RP_ID,
    requireUserVerification: false,
  });

  if (!verification.verified || !verification.registrationInfo) {
    throw new ApiError(400, 'Passkey registration could not be verified');
  }

  const currentPasskeys = Array.isArray(user.passkeys) ? user.passkeys : [];
  const nextPasskey = toStoredPasskey(verification.registrationInfo.credential);

  const deduped = currentPasskeys.filter((entry) => entry.id !== nextPasskey.id);
  deduped.push(nextPasskey);

  await docRef.update({
    passkeys: deduped,
    passkeyUpdatedAt: FieldValue.serverTimestamp(),
  });

  return { verified: true, passkeyId: nextPasskey.id };
}

async function getAuthenticationOptionsForUsername(username) {
  assertPasskeysEnabled();

  const { user } = await getUserByUsername(username);
  const passkeys = Array.isArray(user.passkeys) ? user.passkeys : [];

  if (passkeys.length === 0) {
    throw new ApiError(400, 'No passkeys registered for this account');
  }

  const options = await generateAuthenticationOptions({
    rpID: env.PASSKEY_RP_ID,
    timeout: 60000,
    userVerification: 'preferred',
    allowCredentials: passkeys.map((passkey) => ({
      id: passkey.id,
      type: 'public-key',
      transports: passkey.transports || [],
    })),
  });

  saveChallenge(usernameToKey(user.username), options.challenge, 'login', user.id);

  return options;
}

async function verifyAuthenticationForUsername(username, response) {
  assertPasskeysEnabled();

  const { user, docRef } = await getUserByUsername(username);
  const challenge = consumeChallenge(usernameToKey(user.username), 'login');

  if (challenge.userId !== user.id) {
    throw new ApiError(400, 'Passkey challenge user mismatch');
  }

  const passkeys = Array.isArray(user.passkeys) ? user.passkeys : [];
  const currentPasskey = passkeys.find((entry) => entry.id === response.id);

  if (!currentPasskey) {
    throw new ApiError(400, 'Unknown passkey credential');
  }

  const verification = await verifyAuthenticationResponse({
    response,
    expectedChallenge: challenge.challenge,
    expectedOrigin: env.PASSKEY_RP_ORIGINS,
    expectedRPID: env.PASSKEY_RP_ID,
    credential: passkeyToAuthenticator(currentPasskey),
    requireUserVerification: false,
  });

  if (!verification.verified) {
    throw new ApiError(401, 'Passkey authentication failed');
  }

  const nextPasskeys = passkeys.map((entry) =>
    entry.id === currentPasskey.id
      ? {
          ...entry,
          counter: verification.authenticationInfo.newCounter,
          lastUsedAt: new Date().toISOString(),
        }
      : entry,
  );

  await docRef.update({
    passkeys: nextPasskeys,
    lastLoginAt: FieldValue.serverTimestamp(),
  });

  return buildAuthPayload(user);
}

module.exports = {
  getRegistrationOptionsForUser,
  verifyRegistrationForUser,
  getAuthenticationOptionsForUsername,
  verifyAuthenticationForUsername,
};
