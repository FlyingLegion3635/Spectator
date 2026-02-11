const { z } = require('zod');
const { ROLES } = require('../constants/roles');

const username = z.string().trim().min(2).max(50);
const email = z.string().trim().email().max(200);
const teamNumber = z.string().trim().min(1).max(20);
const password = z.string().min(6).max(128);

const signupSchema = z
  .object({
    username,
    email,
    teamNumber,
    password,
    role: z
      .enum([ROLES.TEAM_MANAGER, ROLES.SCOUTER])
      .optional()
      .default(ROLES.SCOUTER),
    inviteCode: z.string().trim().length(64).optional(),
  })
  .refine(
    (value) =>
      value.role !== ROLES.SCOUTER ||
      (value.inviteCode && value.inviteCode.length === 64),
    {
      message: 'Student signup requires a valid invite code',
      path: ['inviteCode'],
    },
  );

const loginSchema = z.object({
  username,
  password,
});

module.exports = { signupSchema, loginSchema };
