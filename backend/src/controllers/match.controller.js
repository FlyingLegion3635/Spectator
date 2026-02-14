const { asyncHandler } = require('../utils/asyncHandler');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const {
  createMatchEntry,
  listMatchEntries,
  getMatchEntryById,
  listMatchEntryVersions,
  updateMatchEntryById,
  restoreMatchEntryVersion,
  getTeamSummary,
} = require('../services/match.service');

async function filterVisibleEntries(entries, requesterTeamNumber) {
  const requesterTeam = String(requesterTeamNumber || '').trim();
  const uniqueTeams = [
    ...new Set(
      entries
        .map((entry) => String(entry.teamNumber || '').trim())
        .filter((teamNumber) => teamNumber && teamNumber !== requesterTeam),
    ),
  ];

  if (uniqueTeams.length === 0) {
    return entries;
  }

  const snapshots = await Promise.all(
    uniqueTeams.map((teamNumber) =>
      db.collection(COLLECTIONS.ABOUT_PROFILES).doc(teamNumber).get(),
    ),
  );

  const publicTeams = new Set();
  snapshots.forEach((snap) => {
    if (!snap.exists) {
      return;
    }

    const data = snap.data() || {};
    if (String(data.dataVisibility || '') === 'public') {
      const teamNumber = String(data.teamNumber || snap.id).trim();
      if (teamNumber) {
        publicTeams.add(teamNumber);
      }
    }
  });

  return entries.filter((entry) => {
    const teamNumber = String(entry.teamNumber || '').trim();
    if (!teamNumber) {
      return false;
    }

    if (requesterTeam && teamNumber === requesterTeam) {
      return true;
    }

    return publicTeams.has(teamNumber);
  });
}

const postMatchEntry = asyncHandler(async (req, res) => {
  const entry = await createMatchEntry(req.body, req.user);
  res.status(201).json({ success: true, entry });
});

const getMatchEntries = asyncHandler(async (req, res) => {
  const query = { ...req.query };
  const hasSearchFilter = Boolean(
    String(query.teamNumber || '').trim() || String(query.matchNumber || '').trim(),
  );
  const includeAllTeams = String(query.scope || 'team') === 'all';

  if (!req.user && !hasSearchFilter) {
    res.json({ success: true, entries: [] });
    return;
  }

  if (req.user && !includeAllTeams) {
    query.teamNumber = String(req.user.teamNumber || '').trim();
  }

  const entries = await listMatchEntries(query);
  const visibleEntries = await filterVisibleEntries(entries, req.user?.teamNumber);
  res.json({ success: true, entries: visibleEntries });
});

const getMatchEntry = asyncHandler(async (req, res) => {
  const entry = await getMatchEntryById(req.params.id);
  res.json({ success: true, entry });
});

const putMatchEntry = asyncHandler(async (req, res) => {
  const entry = await updateMatchEntryById(req.params.id, req.body, req.user);
  res.json({ success: true, entry });
});

const getMatchEntryVersions = asyncHandler(async (req, res) => {
  const versions = await listMatchEntryVersions(req.params.id);
  res.json({ success: true, versions });
});

const postRestoreMatchEntryVersion = asyncHandler(async (req, res) => {
  const entry = await restoreMatchEntryVersion(req.params.id, req.body.version, req.user);
  res.json({ success: true, entry });
});

const getSummary = asyncHandler(async (req, res) => {
  const summary = await getTeamSummary(req.params.teamNumber);
  res.json({ success: true, summary });
});

module.exports = {
  postMatchEntry,
  getMatchEntries,
  getMatchEntry,
  putMatchEntry,
  getMatchEntryVersions,
  postRestoreMatchEntryVersion,
  getSummary,
};
