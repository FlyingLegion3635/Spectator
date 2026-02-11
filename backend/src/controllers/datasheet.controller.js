const { asyncHandler } = require('../utils/asyncHandler');
const {
  createDatasheet,
  listDatasheets,
  exportDatasheetCsv,
} = require('../services/datasheet.service');

const postDatasheet = asyncHandler(async (req, res) => {
  const datasheet = await createDatasheet(req.body, req.user);
  res.status(201).json({ success: true, datasheet });
});

const getDatasheets = asyncHandler(async (req, res) => {
  const datasheets = await listDatasheets(req.query, req.user);
  res.json({ success: true, datasheets });
});

const getDatasheetExportCsv = asyncHandler(async (req, res) => {
  const data = await exportDatasheetCsv(req.params.id, req.user);

  res.json({
    success: true,
    datasheet: data.datasheet,
    export: {
      pitCsv: data.pitCsv,
      matchCsv: data.matchCsv,
    },
  });
});

module.exports = {
  postDatasheet,
  getDatasheets,
  getDatasheetExportCsv,
};
