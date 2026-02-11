const { asyncHandler } = require('../utils/asyncHandler');
const {
  listEvents,
  createEvent,
  listMatchesByEvent,
  upsertMatchesForEvent,
} = require('../services/events.service');

const getEvents = asyncHandler(async (req, res) => {
  const events = await listEvents(req.query);
  res.json({ success: true, events });
});

const postEvent = asyncHandler(async (req, res) => {
  const event = await createEvent(req.body, req.user.userId);
  res.status(201).json({ success: true, event });
});

const getMatchesForEvent = asyncHandler(async (req, res) => {
  const matches = await listMatchesByEvent(req.params.eventId);
  res.json({ success: true, eventId: req.params.eventId, matches });
});

const putMatchesForEvent = asyncHandler(async (req, res) => {
  const result = await upsertMatchesForEvent(
    req.params.eventId,
    req.body.matches,
    req.user.userId,
  );

  res.json({ success: true, ...result });
});

module.exports = {
  getEvents,
  postEvent,
  getMatchesForEvent,
  putMatchesForEvent,
};
