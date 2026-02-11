const { asyncHandler } = require('../utils/asyncHandler');
const {
  createMatchEntry,
  listMatchEntries,
  getMatchEntryById,
  listMatchEntryVersions,
  updateMatchEntryById,
  restoreMatchEntryVersion,
  getTeamSummary,
} = require('../services/match.service');

const postMatchEntry = asyncHandler(async (req, res) => {
  const entry = await createMatchEntry(req.body, req.user);
  res.status(201).json({ success: true, entry });
});

const getMatchEntries = asyncHandler(async (req, res) => {
  const query = { ...req.query };
  const hasSearchFilter = Boolean(
    String(query.teamNumber || '').trim() || String(query.matchNumber || '').trim(),
  );

  if (!req.user && !hasSearchFilter) {
    res.json({ success: true, entries: [] });
    return;
  }

  if (req.user && !String(query.teamNumber || '').trim()) {
    query.teamNumber = String(req.user.teamNumber || '').trim();
  }

  const entries = await listMatchEntries(query);
  res.json({ success: true, entries });
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
