const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { serializeDoc } = require('../utils/serialize');

const DEFAULT_PROFILE = {
  teamNumber: '3635',
  title: 'FRC 3635 - The Flying Legion',
  mission:
    'Spectator is built for scouting with reliability, clarity, and speed for competition weekends.',
  sponsors: ['Default Sponsor A', 'Default Sponsor B'],
  website: 'https://www.thebluealliance.com/team/3635',
  socialLinks: [],
  isDefault: true,
};

function resolveTeamNumber(teamNumber, user) {
  const explicit = String(teamNumber || '').trim();
  if (explicit) return explicit;

  const fromUser = String(user?.teamNumber || '').trim();
  if (fromUser) return fromUser;

  return '3635';
}

async function getAboutProfile({ teamNumber }, user) {
  const resolvedTeam = resolveTeamNumber(teamNumber, user);
  const docRef = db.collection(COLLECTIONS.ABOUT_PROFILES).doc(resolvedTeam);
  const snap = await docRef.get();

  if (!snap.exists) {
    if (resolvedTeam === '3635') {
      return DEFAULT_PROFILE;
    }

    return {
      ...DEFAULT_PROFILE,
      teamNumber: resolvedTeam,
      isDefault: true,
    };
  }

  return {
    ...serializeDoc(snap),
    isDefault: false,
  };
}

async function upsertAboutProfile(payload, user) {
  const resolvedTeam = resolveTeamNumber(payload.teamNumber, user);
  const docRef = db.collection(COLLECTIONS.ABOUT_PROFILES).doc(resolvedTeam);

  await docRef.set(
    {
      teamNumber: resolvedTeam,
      title: payload.title,
      mission: payload.mission,
      sponsors: payload.sponsors || [],
      website: payload.website || '',
      socialLinks: payload.socialLinks || [],
      updatedByUserId: user.userId,
      updatedByUsername: user.username,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const snap = await docRef.get();
  return serializeDoc(snap);
}

module.exports = {
  getAboutProfile,
  upsertAboutProfile,
};
