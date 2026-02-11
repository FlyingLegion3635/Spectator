const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { ApiError } = require('../utils/apiError');
const { serializeDoc } = require('../utils/serialize');

function getUserTeamNumber(user) {
  const teamNumber = String(user.teamNumber || '').trim();
  if (!teamNumber) {
    throw new ApiError(400, 'Authenticated user has no team number');
  }

  return teamNumber;
}

async function createDatasheet(payload, user) {
  const teamNumber = getUserTeamNumber(user);

  const docRef = await db.collection(COLLECTIONS.DATASHEETS).add({
    teamNumber,
    season: payload.season,
    name: payload.name,
    description: payload.description || '',
    status: 'active',
    createdByUserId: user.userId,
    createdByUsername: user.username,
    createdAt: FieldValue.serverTimestamp(),
  });

  const snap = await docRef.get();
  return serializeDoc(snap);
}

async function listDatasheets({ teamNumber, season, limit = 50 }, user) {
  const effectiveTeam = String(teamNumber || user?.teamNumber || '').trim();

  let query = db.collection(COLLECTIONS.DATASHEETS).limit(limit);

  if (effectiveTeam) {
    query = query.where('teamNumber', '==', effectiveTeam);
  }

  if (season) {
    query = query.where('season', '==', season);
  }

  const snapshot = await query.get();
  return snapshot.docs
    .map(serializeDoc)
    .sort((a, b) => Number(b.season || 0) - Number(a.season || 0));
}

function toCsv(items, headers) {
  const safe = (value) => {
    const text = String(value == null ? '' : value);
    if (text.includes(',') || text.includes('"') || text.includes('\n')) {
      return `"${text.replace(/"/g, '""')}"`;
    }

    return text;
  };

  const rows = [headers.join(',')];

  for (const item of items) {
    rows.push(headers.map((header) => safe(item[header])).join(','));
  }

  return rows.join('\n');
}

async function exportDatasheetCsv(datasheetId, user) {
  const teamNumber = getUserTeamNumber(user);

  const datasheetSnap = await db.collection(COLLECTIONS.DATASHEETS).doc(datasheetId).get();
  if (!datasheetSnap.exists) {
    throw new ApiError(404, 'Datasheet not found');
  }

  const datasheet = serializeDoc(datasheetSnap);
  if (String(datasheet.teamNumber) !== teamNumber) {
    throw new ApiError(403, 'Cannot export datasheet from another team');
  }

  const [pitSnap, matchSnap] = await Promise.all([
    db
      .collection(COLLECTIONS.PIT_ENTRIES)
      .where('datasheetId', '==', datasheetId)
      .limit(2000)
      .get(),
    db
      .collection(COLLECTIONS.MATCH_ENTRIES)
      .where('datasheetId', '==', datasheetId)
      .limit(4000)
      .get(),
  ]);

  const pitEntries = pitSnap.docs.map(serializeDoc);
  const matchEntries = matchSnap.docs.map(serializeDoc);

  const pitCsv = toCsv(pitEntries, [
    'id',
    'teamNumber',
    'teamName',
    'humanPlayerConfidence',
    'driveTrain',
    'mainScoringPotential',
    'pointsInAutonomous',
    'teleOperatedCapabilities',
    'version',
    'createdAt',
    'updatedAt',
  ]);

  const matchCsv = toCsv(matchEntries, [
    'id',
    'teamNumber',
    'matchNumber',
    'allianceColor',
    'shotsAttempted',
    'accuracy',
    'calculatedPoints',
    'scoutedAt',
    'createdAt',
  ]);

  return {
    datasheet,
    pitCsv,
    matchCsv,
  };
}

module.exports = {
  createDatasheet,
  listDatasheets,
  exportDatasheetCsv,
};
