const { getApps, initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { env } = require('./env');

const firebasePrivateKey = env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');

const app = getApps().length
  ? getApps()[0]
  : initializeApp({
      credential: cert({
        projectId: env.FIREBASE_PROJECT_ID,
        clientEmail: env.FIREBASE_CLIENT_EMAIL,
        privateKey: firebasePrivateKey,
      }),
      projectId: env.FIREBASE_PROJECT_ID,
      storageBucket: env.FIREBASE_STORAGE_BUCKET,
      databaseURL: env.FIREBASE_DATABASE_URL,
    });

const db = getFirestore(app);
db.settings({ ignoreUndefinedProperties: true });

module.exports = { db };
