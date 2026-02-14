const { asyncHandler } = require('../utils/asyncHandler');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const {
  createPitEntry,
  listPitEntries,
  getPitEntryById,
  listPitEntryVersions,
  updatePitEntryById,
  restorePitEntryVersion,
} = require('../services/pit.service');

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

const postPitEntry = asyncHandler(async (req, res) => {
  const entry = await createPitEntry(req.body, req.user);
  res.status(201).json({ success: true, entry });
});

const getPitEntries = asyncHandler(async (req, res) => {
  const query = { ...req.query };
  const hasSearchFilter = Boolean(
    String(query.teamNumber || '').trim() || String(query.teamName || '').trim(),
  );
  const includeAllTeams = String(query.scope || 'team') === 'all';

  if (!req.user && !hasSearchFilter) {
    res.json({ success: true, entries: [] });
    return;
  }

  if (req.user && !includeAllTeams) {
    query.teamNumber = String(req.user.teamNumber || '').trim();
  }

  const entries = await listPitEntries(query);
  const visibleEntries = await filterVisibleEntries(entries, req.user?.teamNumber);
  res.json({ success: true, entries: visibleEntries });
});

const getPitEntry = asyncHandler(async (req, res) => {
  const entry = await getPitEntryById(req.params.id);
  res.json({ success: true, entry });
});

const putPitEntry = asyncHandler(async (req, res) => {
  const entry = await updatePitEntryById(req.params.id, req.body, req.user);
  res.json({ success: true, entry });
});

const getPitEntryVersions = asyncHandler(async (req, res) => {
  const versions = await listPitEntryVersions(req.params.id);
  res.json({ success: true, versions });
});

const postRestorePitEntryVersion = asyncHandler(async (req, res) => {
  const entry = await restorePitEntryVersion(
    req.params.id,
    req.body.version,
    req.user,
  );
  res.json({ success: true, entry });
});

module.exports = {
  postPitEntry,
  getPitEntries,
  getPitEntry,
  putPitEntry,
  getPitEntryVersions,
  postRestorePitEntryVersion,
};
