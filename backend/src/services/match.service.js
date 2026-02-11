const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { ApiError } = require('../utils/apiError');
const { serializeDoc } = require('../utils/serialize');

async function createMatchEntry(payload, user) {
  const docRef = await db.collection(COLLECTIONS.MATCH_ENTRIES).add({
    ...payload,
    datasheetId: payload.datasheetId || null,
    teamNumber: payload.teamNumber.trim(),
    matchNumber: payload.matchNumber.trim(),
    scoutedAt: payload.scoutedAt || new Date().toISOString(),
    createdByUserId: user.userId,
    createdByUsername: user.username,
    createdAt: FieldValue.serverTimestamp(),
    version: 1,
    versions: [],
  });

  const snap = await docRef.get();
  return serializeDoc(snap);
}

function buildVersionSnapshot(entry, editor) {
  return {
    version: Number(entry.version || 1),
    snapshot: {
      eventId: entry.eventId || null,
      datasheetId: entry.datasheetId || null,
      matchNumber: entry.matchNumber || '',
      teamNumber: entry.teamNumber || '',
      allianceColor: entry.allianceColor || 'Red',
      fireRate: Number(entry.fireRate || 0),
      shotsAttempted: Number(entry.shotsAttempted || 0),
      accuracy: Number(entry.accuracy || 0),
      calculatedPoints: Number(entry.calculatedPoints || 0),
      autoClimb: Boolean(entry.autoClimb),
      climbLevel: entry.climbLevel || 'None',
      scoutedAt: entry.scoutedAt || new Date().toISOString(),
    },
    editedByUserId: editor.userId,
    editedByUsername: editor.username,
    editedAt: new Date().toISOString(),
  };
}

async function listMatchEntries({
  eventId,
  datasheetId,
  teamNumber,
  matchNumber,
  limit = 50,
}) {
  let query = db.collection(COLLECTIONS.MATCH_ENTRIES).limit(limit);

  if (eventId) {
    query = query.where('eventId', '==', eventId);
  }

  if (teamNumber) {
    query = query.where('teamNumber', '==', teamNumber);
  }

  if (datasheetId) {
    query = query.where('datasheetId', '==', datasheetId);
  }

  if (matchNumber) {
    query = query.where('matchNumber', '==', matchNumber);
  }

  const snapshot = await query.get();
  const entries = snapshot.docs.map(serializeDoc);

  return entries.sort((a, b) => (String(a.scoutedAt) < String(b.scoutedAt) ? 1 : -1));
}

async function getMatchEntryById(id) {
  const snap = await db.collection(COLLECTIONS.MATCH_ENTRIES).doc(id).get();

  if (!snap.exists) {
    throw new ApiError(404, 'Match entry not found');
  }

  return serializeDoc(snap);
}

async function listMatchEntryVersions(id) {
  const entry = await getMatchEntryById(id);
  const versions = Array.isArray(entry.versions) ? entry.versions : [];

  return versions
    .slice()
    .sort((a, b) => Number(b.version || 0) - Number(a.version || 0));
}

async function updateMatchEntryById(id, payload, user) {
  const ref = db.collection(COLLECTIONS.MATCH_ENTRIES).doc(id);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new ApiError(404, 'Match entry not found');
  }

  const current = serializeDoc(snap);
  const previousVersions = Array.isArray(current.versions) ? current.versions : [];
  const nextVersionNumber = Number(current.version || 1) + 1;
  const nextVersions = [
    ...previousVersions,
    buildVersionSnapshot(current, user),
  ].slice(-25);

  await ref.update({
    ...payload,
    eventId: payload.eventId || current.eventId || null,
    datasheetId: payload.datasheetId || current.datasheetId || null,
    teamNumber: payload.teamNumber.trim(),
    matchNumber: payload.matchNumber.trim(),
    scoutedAt: payload.scoutedAt || current.scoutedAt || new Date().toISOString(),
    updatedByUserId: user.userId,
    updatedByUsername: user.username,
    updatedAt: FieldValue.serverTimestamp(),
    version: nextVersionNumber,
    versions: nextVersions,
  });

  const updated = await ref.get();
  return serializeDoc(updated);
}

async function restoreMatchEntryVersion(id, versionNumber, user) {
  const ref = db.collection(COLLECTIONS.MATCH_ENTRIES).doc(id);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new ApiError(404, 'Match entry not found');
  }

  const current = serializeDoc(snap);
  const versions = Array.isArray(current.versions) ? current.versions : [];
  const matchedVersion = versions.find(
    (entry) => Number(entry.version) === Number(versionNumber),
  );

  if (!matchedVersion) {
    throw new ApiError(404, `Version ${versionNumber} not found`);
  }

  const nextVersionNumber = Number(current.version || 1) + 1;
  const nextVersions = [
    ...versions,
    buildVersionSnapshot(current, user),
  ].slice(-25);

  const snapshot = matchedVersion.snapshot || {};

  await ref.update({
    eventId: snapshot.eventId || current.eventId || null,
    datasheetId: snapshot.datasheetId || current.datasheetId || null,
    matchNumber: String(snapshot.matchNumber || current.matchNumber || '').trim(),
    teamNumber: String(snapshot.teamNumber || current.teamNumber || '').trim(),
    allianceColor: snapshot.allianceColor || 'Red',
    fireRate: Number(snapshot.fireRate || 0),
    shotsAttempted: Number(snapshot.shotsAttempted || 0),
    accuracy: Number(snapshot.accuracy || 0),
    calculatedPoints: Number(snapshot.calculatedPoints || 0),
    autoClimb: Boolean(snapshot.autoClimb),
    climbLevel: snapshot.climbLevel || 'None',
    scoutedAt: snapshot.scoutedAt || current.scoutedAt || new Date().toISOString(),
    restoredFromVersion: Number(versionNumber),
    updatedByUserId: user.userId,
    updatedByUsername: user.username,
    updatedAt: FieldValue.serverTimestamp(),
    version: nextVersionNumber,
    versions: nextVersions,
  });

  const updated = await ref.get();
  return serializeDoc(updated);
}

async function getTeamSummary(teamNumber) {
  const [pitSnapshot, matchSnapshot] = await Promise.all([
    db
      .collection(COLLECTIONS.PIT_ENTRIES)
      .where('teamNumber', '==', teamNumber)
      .limit(200)
      .get(),
    db
      .collection(COLLECTIONS.MATCH_ENTRIES)
      .where('teamNumber', '==', teamNumber)
      .limit(200)
      .get(),
  ]);

  const pitEntries = pitSnapshot.docs.map(serializeDoc);
  const matchEntries = matchSnapshot.docs.map(serializeDoc);

  const totals = matchEntries.reduce(
    (acc, entry) => {
      acc.matches += 1;
      acc.points += Number(entry.calculatedPoints || 0);
      acc.shots += Number(entry.shotsAttempted || 0);
      acc.accuracy += Number(entry.accuracy || 0);
      return acc;
    },
    { matches: 0, points: 0, shots: 0, accuracy: 0 },
  );

  return {
    teamNumber,
    pitEntryCount: pitEntries.length,
    matchEntryCount: matchEntries.length,
    averagePoints:
      totals.matches > 0 ? Number((totals.points / totals.matches).toFixed(2)) : 0,
    averageAccuracy:
      totals.matches > 0
        ? Number((totals.accuracy / totals.matches).toFixed(3))
        : 0,
    totalShotsAttempted: totals.shots,
    recentPitEntry: pitEntries.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))[0] || null,
    recentMatchEntry:
      matchEntries.sort((a, b) => (String(a.scoutedAt) < String(b.scoutedAt) ? 1 : -1))[0] ||
      null,
  };
}

module.exports = {
  createMatchEntry,
  listMatchEntries,
  getMatchEntryById,
  listMatchEntryVersions,
  updateMatchEntryById,
  restoreMatchEntryVersion,
  getTeamSummary,
};
