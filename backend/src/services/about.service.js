const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { serializeDoc } = require('../utils/serialize');

const DEFAULT_PROFILE = {
  teamNumber: '3635',
  title: 'FRC 3635 - The Flying Legion',
  mission:
    'Spectator is built for scouting with reliability, clarity, and speed for competition weekends.',
  missionMarkdown:
    '## About Us\n\nSpectator is built for scouting with reliability, clarity, and speed for competition weekends.',
  sponsors: ['Default Sponsor A', 'Default Sponsor B'],
  website: 'https://www.thebluealliance.com/team/3635',
  socialLinks: [],
  uiTheme: {
    primaryColor: '#1242F1',
    accentColor: '#FCA10F',
  },
  dataVisibility: 'team_only',
  isDefault: true,
};

function normalizeHexColor(rawValue, fallback) {
  const value = String(rawValue || '').trim().replace('#', '').toUpperCase();
  if (!/^[0-9A-F]{6}$/.test(value)) {
    return fallback;
  }
  return `#${value}`;
}

function normalizeUiTheme(uiTheme) {
  const safeTheme = uiTheme || {};
  return {
    primaryColor: normalizeHexColor(
      safeTheme.primaryColor,
      DEFAULT_PROFILE.uiTheme.primaryColor,
    ),
    accentColor: normalizeHexColor(
      safeTheme.accentColor,
      DEFAULT_PROFILE.uiTheme.accentColor,
    ),
  };
}

function normalizeDataVisibility(value) {
  return value === 'public' ? 'public' : 'team_only';
}

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
      return { ...DEFAULT_PROFILE };
    }

    return {
      ...DEFAULT_PROFILE,
      teamNumber: resolvedTeam,
      isDefault: true,
    };
  }

  const profile = serializeDoc(snap);
  return {
    ...profile,
    missionMarkdown: String(profile.missionMarkdown || profile.mission || '').trim(),
    uiTheme: normalizeUiTheme(profile.uiTheme),
    dataVisibility: normalizeDataVisibility(profile.dataVisibility),
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
      missionMarkdown: payload.missionMarkdown || payload.mission,
      sponsors: payload.sponsors || [],
      website: payload.website || '',
      socialLinks: payload.socialLinks || [],
      ...(payload.uiTheme ? { uiTheme: normalizeUiTheme(payload.uiTheme) } : {}),
      ...(payload.dataVisibility
        ? { dataVisibility: normalizeDataVisibility(payload.dataVisibility) }
        : {}),
      updatedByUserId: user.userId,
      updatedByUsername: user.username,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const snap = await docRef.get();
  const profile = serializeDoc(snap);
  return {
    ...profile,
    missionMarkdown: String(profile.missionMarkdown || profile.mission || '').trim(),
    uiTheme: normalizeUiTheme(profile.uiTheme),
    dataVisibility: normalizeDataVisibility(profile.dataVisibility),
  };
}

module.exports = {
  getAboutProfile,
  upsertAboutProfile,
};
