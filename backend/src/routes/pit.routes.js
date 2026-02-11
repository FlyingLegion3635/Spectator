const { Router } = require('express');
const {
  postPitEntry,
  getPitEntries,
  getPitEntry,
  putPitEntry,
  getPitEntryVersions,
  postRestorePitEntryVersion,
} = require('../controllers/pit.controller');
const { requireAuth, optionalAuth, requireRoles } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { ROLES } = require('../constants/roles');
const {
  createPitEntrySchema,
  updatePitEntrySchema,
  restorePitEntrySchema,
  listPitEntriesQuerySchema,
  pitEntryIdParamSchema,
} = require('../validators/pit.validator');

const router = Router();

router.get(
  '/',
  optionalAuth,
  validate(listPitEntriesQuerySchema, 'query'),
  getPitEntries,
);
router.get(
  '/:id/versions',
  requireAuth,
  validate(pitEntryIdParamSchema, 'params'),
  getPitEntryVersions,
);
router.get('/:id', requireAuth, validate(pitEntryIdParamSchema, 'params'), getPitEntry);
router.post('/', requireAuth, validate(createPitEntrySchema), postPitEntry);
router.put(
  '/:id',
  requireAuth,
  validate(pitEntryIdParamSchema, 'params'),
  validate(updatePitEntrySchema),
  putPitEntry,
);
router.post(
  '/:id/restore',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER]),
  validate(pitEntryIdParamSchema, 'params'),
  validate(restorePitEntrySchema),
  postRestorePitEntryVersion,
);

module.exports = { pitRoutes: router };
