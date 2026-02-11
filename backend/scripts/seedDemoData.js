/* eslint-disable no-console */
const bcrypt = require('bcryptjs');
const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../src/config/firebase');
const { COLLECTIONS } = require('../src/constants/collections');

async function ensureManagerUser() {
  const usernameNormalized = 'manager';
  const usersRef = db.collection(COLLECTIONS.USERS);
  const existing = await usersRef
    .where('usernameNormalized', '==', usernameNormalized)
    .limit(1)
    .get();

  if (!existing.empty) {
    return existing.docs[0].id;
  }

  const passwordHash = await bcrypt.hash('manager123', 12);
  const docRef = await usersRef.add({
    username: 'manager',
    usernameNormalized,
    teamNumber: '0000',
    role: 'manager',
    passwordHash,
    createdAt: FieldValue.serverTimestamp(),
    lastLoginAt: null,
  });

  return docRef.id;
}

async function seedEvent(managerId) {
  const eventRef = await db.collection(COLLECTIONS.EVENTS).add({
    name: 'Sample Regional',
    code: 'SAMPLE-REGIONAL',
    season: 2026,
    location: 'Sample Arena',
    createdBy: managerId,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const matches = [
    { matchNumber: 1, teams: ['1678', '254', '118', '1323', '2056', '1114'] },
    { matchNumber: 2, teams: ['4414', '148', '971', '3847', '1690', '1538'] },
  ];

  const batch = db.batch();
  for (const match of matches) {
    const docId = `${eventRef.id}_${match.matchNumber}`;
    const ref = db.collection(COLLECTIONS.MATCHES).doc(docId);
    batch.set(ref, {
      eventId: eventRef.id,
      ...match,
      updatedBy: managerId,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  return eventRef.id;
}

async function seedStudents(managerId) {
  const names = ['Student 1', 'Student 2', 'Student 3'];
  const batch = db.batch();

  names.forEach((name) => {
    const ref = db.collection(COLLECTIONS.STUDENTS).doc();
    batch.set(ref, {
      name,
      createdBy: managerId,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();
}

async function main() {
  const managerId = await ensureManagerUser();
  const eventId = await seedEvent(managerId);
  await seedStudents(managerId);

  console.log('Seed complete.');
  console.log('manager username: manager');
  console.log('manager password: manager123');
  console.log(`sample eventId: ${eventId}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
