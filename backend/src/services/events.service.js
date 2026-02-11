const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { serializeDoc } = require('../utils/serialize');

async function listEvents({ search, season, limit = 25 }) {
  let query = db.collection(COLLECTIONS.EVENTS).limit(limit);

  if (season) {
    query = query.where('season', '==', season);
  }

  const snapshot = await query.get();
  let events = snapshot.docs.map(serializeDoc);

  if (search) {
    const lower = search.toLowerCase();
    events = events.filter(
      (event) =>
        String(event.name || '').toLowerCase().includes(lower) ||
        String(event.code || '').toLowerCase().includes(lower),
    );
  }

  return events.sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));
}

async function createEvent(payload, userId) {
  const docRef = await db.collection(COLLECTIONS.EVENTS).add({
    ...payload,
    code: payload.code.toUpperCase(),
    createdBy: userId,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const snap = await docRef.get();
  return serializeDoc(snap);
}

async function listMatchesByEvent(eventId) {
  const snapshot = await db
    .collection(COLLECTIONS.MATCHES)
    .where('eventId', '==', eventId)
    .get();

  return snapshot.docs
    .map(serializeDoc)
    .sort((a, b) => Number(a.matchNumber) - Number(b.matchNumber));
}

async function upsertMatchesForEvent(eventId, matches, userId) {
  const batch = db.batch();

  for (const match of matches) {
    const docId = `${eventId}_${match.matchNumber}`;
    const docRef = db.collection(COLLECTIONS.MATCHES).doc(docId);

    batch.set(
      docRef,
      {
        eventId,
        matchNumber: match.matchNumber,
        teams: match.teams,
        updatedBy: userId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await batch.commit();
  return { eventId, upserted: matches.length };
}

module.exports = {
  listEvents,
  createEvent,
  listMatchesByEvent,
  upsertMatchesForEvent,
};
