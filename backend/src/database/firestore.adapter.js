const { getApps, initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { env } = require('../config/env');

function create() {
  const privateKey = env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');

  const app = getApps().length
    ? getApps()[0]
    : initializeApp({
        credential: cert({
          projectId: env.FIREBASE_PROJECT_ID,
          clientEmail: env.FIREBASE_CLIENT_EMAIL,
          privateKey,
        }),
        projectId: env.FIREBASE_PROJECT_ID,
        storageBucket: env.FIREBASE_STORAGE_BUCKET,
        databaseURL: env.FIREBASE_DATABASE_URL,
      });

  const db = getFirestore(app);
  db.settings({ ignoreUndefinedProperties: true });

  return { db, FieldValue };
}

module.exports = { create };
