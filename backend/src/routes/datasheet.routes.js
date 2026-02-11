const { Router } = require('express');
const {
  postDatasheet,
  getDatasheets,
  getDatasheetExportCsv,
} = require('../controllers/datasheet.controller');
const { requireAuth, requireRoles } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { ROLES } = require('../constants/roles');
const {
  createDatasheetSchema,
  listDatasheetsQuerySchema,
  datasheetIdParamSchema,
} = require('../validators/datasheet.validator');

const router = Router();

router.get('/', validate(listDatasheetsQuerySchema, 'query'), getDatasheets);
router.post(
  '/',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER]),
  validate(createDatasheetSchema),
  postDatasheet,
);
router.get(
  '/:id/export',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER, ROLES.SCOUT_MANAGER]),
  validate(datasheetIdParamSchema, 'params'),
  getDatasheetExportCsv,
);

module.exports = { datasheetRoutes: router };
