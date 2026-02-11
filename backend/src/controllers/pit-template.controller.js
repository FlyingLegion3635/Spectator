const { asyncHandler } = require('../utils/asyncHandler');
const { getPitTemplate, upsertPitTemplate } = require('../services/pit-template.service');

const getTemplate = asyncHandler(async (req, res) => {
  const template = await getPitTemplate(req.query, req.user);
  res.json({ success: true, template });
});

const putTemplate = asyncHandler(async (req, res) => {
  const template = await upsertPitTemplate(req.body, req.user);
  res.json({ success: true, template });
});

module.exports = { getTemplate, putTemplate };
