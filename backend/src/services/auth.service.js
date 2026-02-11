const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { env } = require('../config/env');
const { COLLECTIONS } = require('../constants/collections');
const { normalizeRole, ROLES } = require('../constants/roles');
const { ApiError } = require('../utils/apiError');
const { serializeDoc } = require('../utils/serialize');

function toPublicUser(user) {
  const { passwordHash, usernameNormalized, emailNormalized, ...safe } = user;
  return {
    ...safe,
    avatarUrl: buildAvatarUrl(safe.email),
    role: normalizeRole(safe.role),
  };
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function buildAvatarUrl(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) {
    return '';
  }

  const hash = crypto.createHash('md5').update(normalized).digest('hex');
  return `https://www.gravatar.com/avatar/${hash}?d=identicon&s=200`;
}

function hashInviteCode(inviteCode) {
  return crypto
    .createHash('sha256')
    .update(String(inviteCode || '').trim())
    .digest('hex');
}

async function usernameExists(usersRef, usernameNormalized) {
  const duplicate = await usersRef
    .where('usernameNormalized', '==', usernameNormalized)
    .limit(1)
    .get();

  return !duplicate.empty;
}

async function emailExists(usersRef, emailNormalized) {
  const duplicate = await usersRef
    .where('emailNormalized', '==', emailNormalized)
    .limit(1)
    .get();

  return !duplicate.empty;
}

async function teamAlreadyHasManager(usersRef, teamNumber) {
  const duplicate = await usersRef.where('teamNumber', '==', teamNumber).limit(25).get();
  const managers = duplicate.docs
    .map(serializeDoc)
    .filter((user) => normalizeRole(user.role) === ROLES.TEAM_MANAGER);

  return managers.length > 0;
}

async function consumeStudentInvite({ teamNumber, inviteCode }) {
  const inviteHash = hashInviteCode(inviteCode);

  const query = await db
    .collection(COLLECTIONS.STUDENTS)
    .where('teamNumber', '==', teamNumber)
    .where('status', '==', 'invited')
    .where('inviteCodeHash', '==', inviteHash)
    .limit(1)
    .get();

  if (query.empty) {
    throw new ApiError(403, 'Invalid or already used student invite code');
  }

  const doc = query.docs[0];
  const student = serializeDoc(doc);
  return { docRef: doc.ref, student };
}

function signToken(user) {
  const role = normalizeRole(user.role);
  return jwt.sign(
    {
      userId: user.id,
      username: user.username,
      teamNumber: user.teamNumber,
      role,
    },
    env.JWT_SECRET,
    { expiresIn: env.JWT_EXPIRES_IN },
  );
}

function buildAuthPayload(user) {
  return {
    user: toPublicUser(user),
    token: signToken(user),
  };
}

async function createUser({ username, email, teamNumber, password, role, inviteCode }) {
  const usernameNormalized = username.trim().toLowerCase();
  const emailNormalized = normalizeEmail(email);
  const normalizedTeam = teamNumber.trim();
  const normalizedRole = normalizeRole(role);
  const usersRef = db.collection(COLLECTIONS.USERS);

  if (await usernameExists(usersRef, usernameNormalized)) {
    throw new ApiError(409, 'Username already exists');
  }

  if (await emailExists(usersRef, emailNormalized)) {
    throw new ApiError(409, 'Email already exists');
  }

  if (normalizedRole === ROLES.SCOUT_MANAGER) {
    throw new ApiError(403, 'Scout Manager signup is disabled');
  }

  if (normalizedRole === ROLES.TEAM_MANAGER) {
    if (await teamAlreadyHasManager(usersRef, normalizedTeam)) {
      throw new ApiError(409, 'A Team Manager already exists for this team');
    }
  }

  let studentInvite = null;
  if (normalizedRole === ROLES.SCOUTER) {
    if (!String(inviteCode || '').trim()) {
      throw new ApiError(403, 'Student signup requires an invite code');
    }

    studentInvite = await consumeStudentInvite({
      teamNumber: normalizedTeam,
      inviteCode,
    });
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const docRef = await usersRef.add({
    username: username.trim(),
    usernameNormalized,
    email: email.trim(),
    emailNormalized,
    avatarUrl: buildAvatarUrl(email),
    teamNumber: normalizedTeam,
    role: normalizedRole,
    passwordHash,
    createdAt: FieldValue.serverTimestamp(),
    lastLoginAt: null,
  });

  if (studentInvite) {
    await studentInvite.docRef.update({
      status: 'active',
      linkedUserId: docRef.id,
      linkedUsername: username.trim(),
      linkedEmail: email.trim(),
      activatedAt: FieldValue.serverTimestamp(),
      inviteCodeHash: FieldValue.delete(),
    });
  }

  const createdSnap = await docRef.get();
  const createdUser = serializeDoc(createdSnap);
  return buildAuthPayload(createdUser);
}

async function loginUser({ username, password }) {
  const usernameNormalized = username.trim().toLowerCase();

  const userQuery = await db
    .collection(COLLECTIONS.USERS)
    .where('usernameNormalized', '==', usernameNormalized)
    .limit(1)
    .get();

  if (userQuery.empty) {
    throw new ApiError(401, 'Invalid username or password');
  }

  const doc = userQuery.docs[0];
  const user = serializeDoc(doc);

  const matches = await bcrypt.compare(password, user.passwordHash || '');
  if (!matches) {
    throw new ApiError(401, 'Invalid username or password');
  }

  await doc.ref.update({ lastLoginAt: FieldValue.serverTimestamp() });

  return buildAuthPayload(user);
}

async function getUserById(userId) {
  const docSnap = await db.collection(COLLECTIONS.USERS).doc(userId).get();

  if (!docSnap.exists) {
    throw new ApiError(404, 'User not found');
  }

  return toPublicUser(serializeDoc(docSnap));
}

module.exports = {
  createUser,
  loginUser,
  getUserById,
  buildAuthPayload,
};
