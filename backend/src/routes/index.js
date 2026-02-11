const { Router } = require('express');
const { authRoutes } = require('./auth.routes');
const { eventsRoutes } = require('./events.routes');
const { pitRoutes } = require('./pit.routes');
const { matchRoutes } = require('./match.routes');
const { studentsRoutes } = require('./students.routes');
const { tbaRoutes } = require('./tba.routes');
const { aboutRoutes } = require('./about.routes');
const { pitTemplateRoutes } = require('./pit-template.routes');
const { datasheetRoutes } = require('./datasheet.routes');

const apiRouter = Router();

apiRouter.use('/auth', authRoutes);
apiRouter.use('/events', eventsRoutes);
apiRouter.use('/pit-entries', pitRoutes);
apiRouter.use('/match-entries', matchRoutes);
apiRouter.use('/students', studentsRoutes);
apiRouter.use('/tba', tbaRoutes);
apiRouter.use('/about', aboutRoutes);
apiRouter.use('/pit-template', pitTemplateRoutes);
apiRouter.use('/datasheets', datasheetRoutes);

module.exports = { apiRouter };
