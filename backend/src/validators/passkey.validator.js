const { z } = require('zod');

const username = z.string().trim().min(2).max(50);

const registerPasskeyOptionsSchema = z.object({
  username: username.optional(),
  teamNumber: z.string().trim().min(1).max(20).optional(),
});

const registerPasskeyVerifySchema = z.object({
  response: z.record(z.any()),
});

const loginPasskeyOptionsSchema = z.object({
  username,
});

const loginPasskeyVerifySchema = z.object({
  username,
  response: z.record(z.any()),
});

module.exports = {
  registerPasskeyOptionsSchema,
  registerPasskeyVerifySchema,
  loginPasskeyOptionsSchema,
  loginPasskeyVerifySchema,
};
