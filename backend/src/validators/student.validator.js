const { z } = require('zod');
const { ROLES } = require('../constants/roles');

const createStudentSchema = z.object({
  name: z.string().trim().min(2).max(120),
  username: z.string().trim().min(2).max(60).optional(),
  email: z.string().trim().email().max(200).optional(),
  role: z
    .enum([ROLES.SCOUTER, ROLES.SCOUT_MANAGER, ROLES.TEAM_MANAGER])
    .optional()
    .default(ROLES.SCOUTER),
  grade: z.coerce.number().int().min(1).max(12).optional(),
});

const listStudentsQuerySchema = z.object({
  search: z.string().trim().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
});

const studentIdParamSchema = z.object({
  id: z.string().trim().min(1),
});

const assignTaskSchema = z.object({
  studentId: z.string().trim().min(1),
  title: z.string().trim().min(2).max(200),
  description: z.string().trim().max(2000).optional(),
});

const taskIdParamSchema = z.object({
  taskId: z.string().trim().min(1),
});

const updateTaskStatusSchema = z.object({
  status: z.enum(['todo', 'in_progress', 'done']),
});

module.exports = {
  createStudentSchema,
  listStudentsQuerySchema,
  studentIdParamSchema,
  assignTaskSchema,
  taskIdParamSchema,
  updateTaskStatusSchema,
};
