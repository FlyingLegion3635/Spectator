const { Router } = require('express');
const {
  postMatchEntry,
  getMatchEntries,
  getMatchEntry,
  putMatchEntry,
  getMatchEntryVersions,
  postRestoreMatchEntryVersion,
  getSummary,
} = require('../controllers/match.controller');
const { requireAuth, optionalAuth, requireRoles } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { ROLES } = require('../constants/roles');
const {
  matchEntryIdParamSchema,
  createMatchEntrySchema,
  updateMatchEntrySchema,
  restoreMatchEntrySchema,
  listMatchEntriesQuerySchema,
  teamSummaryParamSchema,
} = require('../validators/match.validator');

const router = Router();

router.get(
  '/',
  optionalAuth,
  validate(listMatchEntriesQuerySchema, 'query'),
  getMatchEntries,
);
router.get(
  '/team/:teamNumber/summary',
  validate(teamSummaryParamSchema, 'params'),
  getSummary,
);
router.get(
  '/:id/versions',
  requireAuth,
  validate(matchEntryIdParamSchema, 'params'),
  getMatchEntryVersions,
);
router.get('/:id', requireAuth, validate(matchEntryIdParamSchema, 'params'), getMatchEntry);
router.post('/', requireAuth, validate(createMatchEntrySchema), postMatchEntry);
router.put(
  '/:id',
  requireAuth,
  validate(matchEntryIdParamSchema, 'params'),
  validate(updateMatchEntrySchema),
  putMatchEntry,
);
router.post(
  '/:id/restore',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER]),
  validate(matchEntryIdParamSchema, 'params'),
  validate(restoreMatchEntrySchema),
  postRestoreMatchEntryVersion,
);

module.exports = { matchRoutes: router };
