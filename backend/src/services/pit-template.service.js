const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { serializeDoc } = require('../utils/serialize');

const DEFAULT_FIELDS = [
  {
    key: 'canClimb',
    label: 'Can Climb',
    type: 'checkbox',
    required: false,
  },
  {
    key: 'canShoot',
    label: 'Can Shoot',
    type: 'checkbox',
    required: false,
  },
  {
    key: 'driveTrainType',
    label: 'Drive Train Type',
    type: 'select',
    options: ['Tank', 'Swerve', 'Mecanum', 'Other'],
    required: false,
  },
];

function resolveTeamNumber(teamNumber, user) {
  const explicit = String(teamNumber || '').trim();
  if (explicit) return explicit;
  return String(user?.teamNumber || '').trim();
}

async function getPitTemplate({ teamNumber }, user) {
  const resolved = resolveTeamNumber(teamNumber, user);
  if (!resolved) {
    return {
      teamNumber: '',
      fields: DEFAULT_FIELDS,
      isDefault: true,
    };
  }

  const snap = await db.collection(COLLECTIONS.PIT_TEMPLATES).doc(resolved).get();

  if (!snap.exists) {
    return {
      teamNumber: resolved,
      fields: DEFAULT_FIELDS,
      isDefault: true,
    };
  }

  return {
    ...serializeDoc(snap),
    isDefault: false,
  };
}

async function upsertPitTemplate(payload, user) {
  const resolved = resolveTeamNumber(payload.teamNumber, user);

  const docRef = db.collection(COLLECTIONS.PIT_TEMPLATES).doc(resolved);
  await docRef.set(
    {
      teamNumber: resolved,
      fields: payload.fields,
      updatedByUserId: user.userId,
      updatedByUsername: user.username,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const snap = await docRef.get();
  return serializeDoc(snap);
}

module.exports = {
  getPitTemplate,
  upsertPitTemplate,
};
