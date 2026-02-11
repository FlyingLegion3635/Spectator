const { asyncHandler } = require('../utils/asyncHandler');
const { getAboutProfile, upsertAboutProfile } = require('../services/about.service');

const getProfile = asyncHandler(async (req, res) => {
  const profile = await getAboutProfile(req.query, req.user);
  res.json({ success: true, profile });
});

const putProfile = asyncHandler(async (req, res) => {
  const profile = await upsertAboutProfile(req.body, req.user);
  res.json({ success: true, profile });
});

module.exports = { getProfile, putProfile };
