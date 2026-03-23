const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { db, FieldValue } = require('../database');
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
    status: safe.status || 'active',
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

async function usernameExistsInTeam(usersRef, usernameNormalized, teamNumber) {
  const duplicate = await usersRef
    .where('usernameNormalized', '==', usernameNormalized)
    .where('teamNumber', '==', teamNumber)
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
    throw new ApiError(403, 'Invalid or already used invite key');
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
      status: user.status || 'active',
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

  if (await usernameExistsInTeam(usersRef, usernameNormalized, normalizedTeam)) {
    throw new ApiError(409, 'Username already exists on this team');
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
      throw new ApiError(403, 'Signup requires a team invite key');
    }

    studentInvite = await consumeStudentInvite({
      teamNumber: normalizedTeam,
      inviteCode,
    });
  }

  // Team managers are active immediately; scouters require approval
  const userStatus = normalizedRole === ROLES.TEAM_MANAGER ? 'active' : 'pending';

  const passwordHash = await bcrypt.hash(password, 12);

  const docRef = await usersRef.add({
    username: username.trim(),
    usernameNormalized,
    email: email.trim(),
    emailNormalized,
    avatarUrl: buildAvatarUrl(email),
    teamNumber: normalizedTeam,
    role: normalizedRole,
    status: userStatus,
    passwordHash,
    createdAt: FieldValue.serverTimestamp(),
    lastLoginAt: null,
  });

  if (studentInvite) {
    await studentInvite.docRef.update({
      status: 'pending',
      linkedUserId: docRef.id,
      linkedUsername: username.trim(),
      linkedEmail: email.trim(),
    });
  }

  const createdSnap = await docRef.get();
  const createdUser = serializeDoc(createdSnap);
  return buildAuthPayload(createdUser);
}

async function loginUser({ username, password, teamNumber }) {
  const usernameNormalized = username.trim().toLowerCase();
  const normalizedTeam = String(teamNumber || '').trim();

  if (!normalizedTeam) {
    throw new ApiError(400, 'Team number is required for login');
  }

  const userQuery = await db
    .collection(COLLECTIONS.USERS)
    .where('usernameNormalized', '==', usernameNormalized)
    .where('teamNumber', '==', normalizedTeam)
    .limit(1)
    .get();

  if (userQuery.empty) {
    throw new ApiError(401, 'Invalid username, team number, or password');
  }

  const doc = userQuery.docs[0];
  const user = serializeDoc(doc);

  const matches = await bcrypt.compare(password, user.passwordHash || '');
  if (!matches) {
    throw new ApiError(401, 'Invalid username, team number, or password');
  }

  // Backfill status for existing users who predate the approval system
  const updateFields = { lastLoginAt: FieldValue.serverTimestamp() };
  if (!user.status) {
    updateFields.status = 'active';
    user.status = 'active';
  }

  await doc.ref.update(updateFields);

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
