const { Router } = require('express');
const {
  getStudents,
  postStudent,
  deleteStudent,
  postTask,
  patchTaskStatus,
} = require('../controllers/students.controller');
const { requireAuth, requireRoles } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { ROLES } = require('../constants/roles');
const {
  createStudentSchema,
  listStudentsQuerySchema,
  studentIdParamSchema,
  assignTaskSchema,
  taskIdParamSchema,
  updateTaskStatusSchema,
} = require('../validators/student.validator');

const router = Router();

router.get('/', requireAuth, validate(listStudentsQuerySchema, 'query'), getStudents);
router.post(
  '/invite',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER]),
  validate(createStudentSchema),
  postStudent,
);
router.delete(
  '/:id',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER]),
  validate(studentIdParamSchema, 'params'),
  deleteStudent,
);
router.post(
  '/tasks',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER, ROLES.SCOUT_MANAGER]),
  validate(assignTaskSchema),
  postTask,
);
router.patch(
  '/tasks/:taskId/status',
  requireAuth,
  requireRoles([ROLES.TEAM_MANAGER, ROLES.SCOUT_MANAGER, ROLES.SCOUTER]),
  validate(taskIdParamSchema, 'params'),
  validate(updateTaskStatusSchema),
  patchTaskStatus,
);

module.exports = { studentsRoutes: router };
