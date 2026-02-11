const { Router } = require('express');
const { getProfile, putProfile } = require('../controllers/about.controller');
const { requireAuth, requireRoles } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { ROLES } = require('../constants/roles');
const {
  getAboutProfileQuerySchema,
  upsertAboutProfileSchema,
} = require('../validators/about.validator');

const router = Router();

router.get('/profile', validate(getAboutProfileQuerySchema, 'query'), getProfile);
router.put(
  '/profile',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER]),
  validate(upsertAboutProfileSchema),
  putProfile,
);

module.exports = { aboutRoutes: router };
