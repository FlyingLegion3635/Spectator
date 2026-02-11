const { Router } = require('express');
const {
  getTeamInfo,
  getTeamLogo,
  getTeamEvents,
  getEventMatches,
  getTranslatedKeys,
} = require('../controllers/tba.controller');
const { validate } = require('../middleware/validate');
const {
  teamNumberParamSchema,
  teamAndYearParamSchema,
  eventKeyParamSchema,
  translateQuerySchema,
} = require('../validators/tba.validator');

const router = Router();

router.get('/team/:teamNumber', validate(teamNumberParamSchema, 'params'), getTeamInfo);
router.get('/team/:teamNumber/logo', validate(teamNumberParamSchema, 'params'), getTeamLogo);
router.get(
  '/team/:teamNumber/events/:year',
  validate(teamAndYearParamSchema, 'params'),
  getTeamEvents,
);
router.get('/event/:eventKey/matches', validate(eventKeyParamSchema, 'params'), getEventMatches);
router.get('/translate', validate(translateQuerySchema, 'query'), getTranslatedKeys);

module.exports = { tbaRoutes: router };
