const { asyncHandler } = require('../utils/asyncHandler');
const {
  createPitEntry,
  listPitEntries,
  getPitEntryById,
  listPitEntryVersions,
  updatePitEntryById,
  restorePitEntryVersion,
} = require('../services/pit.service');

const postPitEntry = asyncHandler(async (req, res) => {
  const entry = await createPitEntry(req.body, req.user);
  res.status(201).json({ success: true, entry });
});

const getPitEntries = asyncHandler(async (req, res) => {
  const query = { ...req.query };
  const hasSearchFilter = Boolean(
    String(query.teamNumber || '').trim() || String(query.teamName || '').trim(),
  );

  if (!req.user && !hasSearchFilter) {
    res.json({ success: true, entries: [] });
    return;
  }

  if (req.user && !String(query.teamNumber || '').trim()) {
    query.teamNumber = String(req.user.teamNumber || '').trim();
  }

  const entries = await listPitEntries(query);
  res.json({ success: true, entries });
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
