const dotenv = require('dotenv');

dotenv.config();

function parseBoolean(value, fallback) {
  if (value === undefined) return fallback;
  return value === 'true';
}

function parseList(value, fallback = []) {
  if (!value || typeof value !== 'string') {
    return fallback;
  }

  return value
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function getEnv(name, fallback = undefined) {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const env = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: Number(process.env.PORT || 4000),
  API_PREFIX: process.env.API_PREFIX || '/api/v1',
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
  JWT_SECRET: getEnv('JWT_SECRET'),
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  ENABLE_SIGNUP: parseBoolean(process.env.ENABLE_SIGNUP, true),
  ENABLE_PASSKEYS: parseBoolean(process.env.ENABLE_PASSKEYS, false),
  PASSKEY_RP_ID: process.env.PASSKEY_RP_ID || 'localhost',
  PASSKEY_RP_NAME: process.env.PASSKEY_RP_NAME || 'Spectator',
  PASSKEY_RP_ORIGIN: process.env.PASSKEY_RP_ORIGIN || 'http://localhost:3000',
  PASSKEY_RP_ORIGINS: parseList(process.env.PASSKEY_RP_ORIGINS, [
    process.env.PASSKEY_RP_ORIGIN || 'http://localhost:3000',
  ]),
  FIREBASE_PROJECT_ID: getEnv('FIREBASE_PROJECT_ID'),
  FIREBASE_CLIENT_EMAIL: getEnv('FIREBASE_CLIENT_EMAIL'),
  FIREBASE_PRIVATE_KEY: getEnv('FIREBASE_PRIVATE_KEY'),
  FIREBASE_STORAGE_BUCKET: process.env.FIREBASE_STORAGE_BUCKET,
  FIREBASE_DATABASE_URL: process.env.FIREBASE_DATABASE_URL,
  TBA_API_KEY: process.env.TBA_API_KEY || '',
};

module.exports = { env };
