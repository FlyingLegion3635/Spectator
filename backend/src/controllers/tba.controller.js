const { asyncHandler } = require('../utils/asyncHandler');
const {
  fetchTeamInfo,
  fetchTeamLogo,
  fetchTeamEvents,
  fetchEventMatches,
  translateKeys,
} = require('../services/tba.service');

const getTeamInfo = asyncHandler(async (req, res) => {
  const team = await fetchTeamInfo(req.params.teamNumber);
  res.json({ success: true, team });
});

const getTeamLogo = asyncHandler(async (req, res) => {
  const logoUrl = await fetchTeamLogo(req.params.teamNumber);
  res.json({ success: true, logoUrl });
});

const getTeamEvents = asyncHandler(async (req, res) => {
  const events = await fetchTeamEvents(req.params.teamNumber, req.params.year);
  res.json({ success: true, events });
});

const getEventMatches = asyncHandler(async (req, res) => {
  const matches = await fetchEventMatches(req.params.eventKey);
  res.json({ success: true, matches });
});

const getTranslatedKeys = asyncHandler(async (req, res) => {
  const translation = translateKeys(req.query);
  res.json({ success: true, translation });
});

module.exports = {
  getTeamInfo,
  getTeamLogo,
  getTeamEvents,
  getEventMatches,
  getTranslatedKeys,
};
