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

const DB_TYPE = process.env.DB_TYPE || 'firestore';

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

  // Database type: 'firestore', 'sql', or 'mongo'
  DB_TYPE,

  // SQL configuration (when DB_TYPE=sql)
  // DB_CLIENT supports: pg, mysql, mysql2, mariadb (via mysql2), sqlite3, mssql (via tedious)
  DB_CLIENT: process.env.DB_CLIENT || 'pg',
  DB_HOST: process.env.DB_HOST || 'localhost',
  DB_PORT: process.env.DB_PORT || '',
  DB_USER: process.env.DB_USER || '',
  DB_PASSWORD: process.env.DB_PASSWORD || '',
  DB_NAME: process.env.DB_NAME || 'spectator',

  // MongoDB configuration (when DB_TYPE=mongo)
  MONGO_URI: process.env.MONGO_URI || 'mongodb://localhost:27017',
  MONGO_DB_NAME: process.env.MONGO_DB_NAME || 'spectator',

  // Firebase/Firestore configuration (when DB_TYPE=firestore)
  FIREBASE_PROJECT_ID: DB_TYPE === 'firestore' ? getEnv('FIREBASE_PROJECT_ID') : process.env.FIREBASE_PROJECT_ID || '',
  FIREBASE_CLIENT_EMAIL: DB_TYPE === 'firestore' ? getEnv('FIREBASE_CLIENT_EMAIL') : process.env.FIREBASE_CLIENT_EMAIL || '',
  FIREBASE_PRIVATE_KEY: DB_TYPE === 'firestore' ? getEnv('FIREBASE_PRIVATE_KEY') : process.env.FIREBASE_PRIVATE_KEY || '',
  FIREBASE_STORAGE_BUCKET: process.env.FIREBASE_STORAGE_BUCKET,
  FIREBASE_DATABASE_URL: process.env.FIREBASE_DATABASE_URL,

  TBA_API_KEY: process.env.TBA_API_KEY || '',
};

module.exports = { env };
