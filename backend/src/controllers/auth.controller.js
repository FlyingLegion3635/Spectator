const { asyncHandler } = require('../utils/asyncHandler');
const { env } = require('../config/env');
const { ApiError } = require('../utils/apiError');
const { createUser, loginUser, getUserById } = require('../services/auth.service');
const {
  getRegistrationOptionsForUser,
  verifyRegistrationForUser,
  getAuthenticationOptionsForUsername,
  verifyAuthenticationForUsername,
} = require('../services/passkey.service');

const signup = asyncHandler(async (req, res) => {
  if (!env.ENABLE_SIGNUP) {
    throw new ApiError(403, 'Signup is disabled by server configuration');
  }

  const result = await createUser(req.body);
  res.status(201).json({ success: true, ...result });
});

const login = asyncHandler(async (req, res) => {
  const result = await loginUser(req.body);
  res.json({ success: true, ...result });
});

const me = asyncHandler(async (req, res) => {
  const user = await getUserById(req.user.userId);
  res.json({ success: true, user });
});

const config = asyncHandler(async (_req, res) => {
  res.json({
    success: true,
    config: {
      signupEnabled: env.ENABLE_SIGNUP,
      passkeysEnabled: env.ENABLE_PASSKEYS,
      signupRoles: ['team_manager', 'scouter'],
      studentInviteRequired: true,
    },
  });
});

const passkeyRegisterOptions = asyncHandler(async (req, res) => {
  const options = await getRegistrationOptionsForUser(req.user.userId, req.body);
  res.json({ success: true, options });
});

const passkeyRegisterVerify = asyncHandler(async (req, res) => {
  const result = await verifyRegistrationForUser(req.user.userId, req.body.response);
  res.json({ success: true, ...result });
});

const passkeyLoginOptions = asyncHandler(async (req, res) => {
  const options = await getAuthenticationOptionsForUsername(req.body.username);
  res.json({ success: true, options });
});

const passkeyLoginVerify = asyncHandler(async (req, res) => {
  const result = await verifyAuthenticationForUsername(
    req.body.username,
    req.body.response,
  );
  res.json({ success: true, ...result });
});

module.exports = {
  signup,
  login,
  me,
  config,
  passkeyRegisterOptions,
  passkeyRegisterVerify,
  passkeyLoginOptions,
  passkeyLoginVerify,
};
