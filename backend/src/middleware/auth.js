const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { ApiError } = require('../utils/apiError');
const { normalizeRole, ROLES } = require('../constants/roles');

function parseBearerToken(authHeader) {
  return authHeader.startsWith('Bearer ')
    ? authHeader.slice(7)
    : undefined;
}

function decodeAuthToken(token) {
  const payload = jwt.verify(token, env.JWT_SECRET);
  return {
    ...payload,
    role: normalizeRole(payload.role),
  };
}

function requireAuth(req, _res, next) {
  const authHeader = req.headers.authorization || '';
  const token = parseBearerToken(authHeader);

  if (!token) {
    return next(new ApiError(401, 'Missing Bearer token'));
  }

  try {
    req.user = decodeAuthToken(token);
    return next();
  } catch (_err) {
    return next(new ApiError(401, 'Invalid or expired token'));
  }
}

function optionalAuth(req, _res, next) {
  const authHeader = req.headers.authorization || '';
  const token = parseBearerToken(authHeader);

  if (!token) {
    return next();
  }

  try {
    req.user = decodeAuthToken(token);
    return next();
  } catch (_err) {
    return next();
  }
}

function requireManager(req, _res, next) {
  if (
    !req.user ||
    (req.user.role !== ROLES.TEAM_MANAGER &&
      req.user.role !== ROLES.SCOUT_MANAGER)
  ) {
    return next(new ApiError(403, 'Manager role required'));
  }

  return next();
}

function requireRoles(allowedRoles) {
  return (req, _res, next) => {
    if (!req.user) {
      return next(new ApiError(401, 'Authentication required'));
    }

    if (!allowedRoles.includes(req.user.role)) {
      return next(new ApiError(403, 'Insufficient role permissions'));
    }

    return next();
  };
}

module.exports = { requireAuth, optionalAuth, requireManager, requireRoles };
