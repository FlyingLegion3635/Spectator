const { Router } = require('express');
const {
  signup,
  login,
  me,
  config,
  passkeyRegisterOptions,
  passkeyRegisterVerify,
  passkeyLoginOptions,
  passkeyLoginVerify,
} = require('../controllers/auth.controller');
const { validate } = require('../middleware/validate');
const { requireAuth } = require('../middleware/auth');
const { signupSchema, loginSchema } = require('../validators/auth.validator');
const {
  registerPasskeyOptionsSchema,
  registerPasskeyVerifySchema,
  loginPasskeyOptionsSchema,
  loginPasskeyVerifySchema,
} = require('../validators/passkey.validator');

const router = Router();

router.get('/config', config);
router.post('/signup', validate(signupSchema), signup);
router.post('/login', validate(loginSchema), login);
router.get('/me', requireAuth, me);
router.post(
  '/passkeys/register/options',
  requireAuth,
  validate(registerPasskeyOptionsSchema),
  passkeyRegisterOptions,
);
router.post(
  '/passkeys/register/verify',
  requireAuth,
  validate(registerPasskeyVerifySchema),
  passkeyRegisterVerify,
);
router.post(
  '/passkeys/login/options',
  validate(loginPasskeyOptionsSchema),
  passkeyLoginOptions,
);
router.post(
  '/passkeys/login/verify',
  validate(loginPasskeyVerifySchema),
  passkeyLoginVerify,
);

module.exports = { authRoutes: router };
