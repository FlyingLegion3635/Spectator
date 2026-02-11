const { Router } = require('express');
const { getTemplate, putTemplate } = require('../controllers/pit-template.controller');
const { requireAuth, requireRoles } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { ROLES } = require('../constants/roles');
const {
  upsertPitTemplateSchema,
  getPitTemplateQuerySchema,
} = require('../validators/pit-template.validator');

const router = Router();

router.get('/', validate(getPitTemplateQuerySchema, 'query'), getTemplate);
router.put(
  '/',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER, ROLES.SCOUT_MANAGER]),
  validate(upsertPitTemplateSchema),
  putTemplate,
);

module.exports = { pitTemplateRoutes: router };
