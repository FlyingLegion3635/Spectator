const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { ApiError } = require('../utils/apiError');
const { serializeDoc } = require('../utils/serialize');

async function createPitEntry(payload, user) {
  const docRef = await db.collection(COLLECTIONS.PIT_ENTRIES).add({
    ...payload,
    datasheetId: payload.datasheetId || null,
    teamNumber: payload.teamNumber.trim(),
    teamName: payload.teamName.trim(),
    createdByUserId: user.userId,
    createdByUsername: user.username,
    createdAt: FieldValue.serverTimestamp(),
    version: 1,
    versions: [],
  });

  const snap = await docRef.get();
  return serializeDoc(snap);
}

async function listPitEntries({
  eventId,
  datasheetId,
  teamNumber,
  teamName,
  limit = 50,
}) {
  let query = db.collection(COLLECTIONS.PIT_ENTRIES).limit(limit);

  if (eventId) {
    query = query.where('eventId', '==', eventId);
  }

  if (datasheetId) {
    query = query.where('datasheetId', '==', datasheetId);
  }

  if (teamNumber) {
    query = query.where('teamNumber', '==', teamNumber);
  }

  const snapshot = await query.get();
  let entries = snapshot.docs.map(serializeDoc);

  if (teamName) {
    const term = teamName.toLowerCase();
    entries = entries.filter((entry) =>
      String(entry.teamName || '').toLowerCase().includes(term),
    );
  }

  return entries.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

async function getPitEntryById(id) {
  const snap = await db.collection(COLLECTIONS.PIT_ENTRIES).doc(id).get();

  if (!snap.exists) {
    throw new ApiError(404, 'Pit entry not found');
  }

  return serializeDoc(snap);
}

async function listPitEntryVersions(id) {
  const entry = await getPitEntryById(id);
  const versions = Array.isArray(entry.versions) ? entry.versions : [];

  return versions
    .slice()
    .sort((a, b) => Number(b.version || 0) - Number(a.version || 0));
}

function buildVersionSnapshot(entry, editor) {
  return {
    version: Number(entry.version || 1),
    snapshot: {
      teamNumber: entry.teamNumber || '',
      teamName: entry.teamName || '',
      humanPlayerConfidence: entry.humanPlayerConfidence || '',
      driveTrain: entry.driveTrain || '',
      mainScoringPotential: entry.mainScoringPotential || '',
      pointsInAutonomous: entry.pointsInAutonomous || '',
      teleOperatedCapabilities: entry.teleOperatedCapabilities || '',
      customResponses: entry.customResponses || {},
      eventId: entry.eventId || null,
    },
    editedByUserId: editor.userId,
    editedByUsername: editor.username,
    editedAt: new Date().toISOString(),
  };
}

async function updatePitEntryById(id, payload, user) {
  const ref = db.collection(COLLECTIONS.PIT_ENTRIES).doc(id);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new ApiError(404, 'Pit entry not found');
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
    datasheetId: payload.datasheetId || current.datasheetId || null,
    teamNumber: payload.teamNumber.trim(),
    teamName: payload.teamName.trim(),
    updatedByUserId: user.userId,
    updatedByUsername: user.username,
    updatedAt: FieldValue.serverTimestamp(),
    version: nextVersionNumber,
    versions: nextVersions,
  });

  const updated = await ref.get();
  return serializeDoc(updated);
}

async function restorePitEntryVersion(id, versionNumber, user) {
  const ref = db.collection(COLLECTIONS.PIT_ENTRIES).doc(id);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new ApiError(404, 'Pit entry not found');
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
    teamNumber: String(snapshot.teamNumber || current.teamNumber || '').trim(),
    teamName: String(snapshot.teamName || current.teamName || '').trim(),
    humanPlayerConfidence: snapshot.humanPlayerConfidence || '',
    driveTrain: snapshot.driveTrain || '',
    mainScoringPotential: snapshot.mainScoringPotential || '',
    pointsInAutonomous: snapshot.pointsInAutonomous || '',
    teleOperatedCapabilities: snapshot.teleOperatedCapabilities || '',
    customResponses: snapshot.customResponses || {},
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

module.exports = {
  createPitEntry,
  listPitEntries,
  getPitEntryById,
  listPitEntryVersions,
  updatePitEntryById,
  restorePitEntryVersion,
};
