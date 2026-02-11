const { Router } = require('express');
const {
  getEvents,
  postEvent,
  getMatchesForEvent,
  putMatchesForEvent,
} = require('../controllers/events.controller');
const { requireAuth, requireManager } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const {
  eventIdParamSchema,
  createEventSchema,
  listEventsQuerySchema,
  upsertMatchesSchema,
} = require('../validators/events.validator');

const router = Router();

router.get('/', validate(listEventsQuerySchema, 'query'), getEvents);
router.post('/', requireAuth, requireManager, validate(createEventSchema), postEvent);
router.get(
  '/:eventId/matches',
  validate(eventIdParamSchema, 'params'),
  getMatchesForEvent,
);
router.put(
  '/:eventId/matches',
  requireAuth,
  requireManager,
  validate(eventIdParamSchema, 'params'),
  validate(upsertMatchesSchema),
  putMatchesForEvent,
);

module.exports = { eventsRoutes: router };
