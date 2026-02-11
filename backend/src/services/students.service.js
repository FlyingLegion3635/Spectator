const { FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');
const { db } = require('../config/firebase');
const { COLLECTIONS } = require('../constants/collections');
const { normalizeRole, ROLES } = require('../constants/roles');
const { ApiError } = require('../utils/apiError');
const { serializeDoc } = require('../utils/serialize');

function requireTeamNumber(user) {
  const teamNumber = String(user.teamNumber || '').trim();
  if (!teamNumber) {
    throw new ApiError(400, 'Authenticated user has no team number');
  }

  return teamNumber;
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function generateInviteCode() {
  return crypto.randomBytes(32).toString('hex');
}

function hashInviteCode(inviteCode) {
  return crypto
    .createHash('sha256')
    .update(String(inviteCode || '').trim())
    .digest('hex');
}

function sanitizeStudent(student, tasks) {
  const { inviteCodeHash, ...safe } = student;
  return {
    ...safe,
    role: normalizeRole(safe.role),
    tasks,
  };
}

async function listStudents({ search, limit = 50 }, user) {
  const teamNumber = requireTeamNumber(user);

  let query = db
    .collection(COLLECTIONS.STUDENTS)
    .where('teamNumber', '==', teamNumber)
    .limit(limit);

  const snapshot = await query.get();
  let students = snapshot.docs.map(serializeDoc);

  if (search) {
    const term = search.toLowerCase();
    students = students.filter((student) =>
      String(student.name || '').toLowerCase().includes(term),
    );
  }

  const studentIds = students.map((student) => student.id);

  if (studentIds.length === 0) {
    return students.map((student) => sanitizeStudent(student, []));
  }

  const tasksSnapshot = await db
    .collection(COLLECTIONS.STUDENT_TASKS)
    .where('teamNumber', '==', teamNumber)
    .limit(1000)
    .get();

  const tasks = tasksSnapshot.docs.map(serializeDoc);

  return students
    .map((student) =>
      sanitizeStudent(
        student,
        tasks.filter((task) => task.studentId === student.id),
      ),
    )
    .sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));
}

async function createStudent(payload, user) {
  const teamNumber = requireTeamNumber(user);
  const inviteCode = generateInviteCode();
  const inviteCodeHash = hashInviteCode(inviteCode);
  const usernameNormalized = String(payload.username || '').trim().toLowerCase();
  const email = String(payload.email || '').trim();
  const emailNormalized = normalizeEmail(email);

  if (usernameNormalized) {
    const duplicateUsername = await db
      .collection(COLLECTIONS.STUDENTS)
      .where('teamNumber', '==', teamNumber)
      .where('usernameNormalized', '==', usernameNormalized)
      .where('status', '==', 'invited')
      .limit(1)
      .get();

    if (!duplicateUsername.empty) {
      throw new ApiError(409, 'Student username already has an active invite');
    }
  }

  if (emailNormalized) {
    const duplicateEmail = await db
      .collection(COLLECTIONS.STUDENTS)
      .where('teamNumber', '==', teamNumber)
      .where('emailNormalized', '==', emailNormalized)
      .where('status', '==', 'invited')
      .limit(1)
      .get();

    if (!duplicateEmail.empty) {
      throw new ApiError(409, 'Student email already has an active invite');
    }
  }

  const docRef = await db.collection(COLLECTIONS.STUDENTS).add({
    teamNumber,
    name: payload.name,
    username: String(payload.username || '').trim(),
    usernameNormalized,
    email,
    emailNormalized,
    role: normalizeRole(payload.role || ROLES.SCOUTER),
    grade: payload.grade || null,
    status: 'invited',
    inviteCodeHash,
    inviteCodeLast6: inviteCode.slice(-6),
    inviteCreatedAt: FieldValue.serverTimestamp(),
    invitedByUserId: user.userId,
    invitedByUsername: user.username,
    createdAt: FieldValue.serverTimestamp(),
  });

  const snap = await docRef.get();
  const student = sanitizeStudent(serializeDoc(snap), []);
  return { student, inviteCode };
}

async function removeStudent(studentId, user) {
  const teamNumber = requireTeamNumber(user);
  const studentRef = db.collection(COLLECTIONS.STUDENTS).doc(studentId);
  const studentSnap = await studentRef.get();

  if (!studentSnap.exists) {
    throw new ApiError(404, 'Student not found');
  }

  const student = serializeDoc(studentSnap);
  if (String(student.teamNumber) !== teamNumber) {
    throw new ApiError(403, 'Cannot remove student from another team');
  }

  const tasksSnapshot = await db
    .collection(COLLECTIONS.STUDENT_TASKS)
    .where('studentId', '==', studentId)
    .limit(1000)
    .get();

  const batch = db.batch();
  batch.delete(studentRef);

  tasksSnapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();

  return { removed: true, studentId };
}

async function assignTask(payload, user) {
  const teamNumber = requireTeamNumber(user);
  const studentSnap = await db.collection(COLLECTIONS.STUDENTS).doc(payload.studentId).get();

  if (!studentSnap.exists) {
    throw new ApiError(404, 'Student not found');
  }

  const student = serializeDoc(studentSnap);
  if (String(student.teamNumber) !== teamNumber) {
    throw new ApiError(403, 'Cannot assign tasks to another team');
  }

  const docRef = await db.collection(COLLECTIONS.STUDENT_TASKS).add({
    teamNumber,
    studentId: payload.studentId,
    assignedToUsername: student.username || '',
    title: payload.title,
    description: payload.description || '',
    status: 'todo',
    assignedByUserId: user.userId,
    assignedByUsername: user.username,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const snap = await docRef.get();
  return serializeDoc(snap);
}

async function updateTaskStatus(taskId, status, user) {
  const teamNumber = requireTeamNumber(user);
  const taskRef = db.collection(COLLECTIONS.STUDENT_TASKS).doc(taskId);
  const taskSnap = await taskRef.get();

  if (!taskSnap.exists) {
    throw new ApiError(404, 'Task not found');
  }

  const task = serializeDoc(taskSnap);

  if (String(task.teamNumber) !== teamNumber) {
    throw new ApiError(403, 'Cannot update task from another team');
  }

  if (normalizeRole(user.role) === ROLES.SCOUTER) {
    const taskUser = String(task.assignedToUsername || '').trim().toLowerCase();
    const actor = String(user.username || '').trim().toLowerCase();

    if (taskUser && taskUser !== actor) {
      throw new ApiError(403, 'Scouters can only mark their own tasks');
    }
  }

  await taskRef.update({
    status,
    updatedByUserId: user.userId,
    updatedByUsername: user.username,
    updatedAt: FieldValue.serverTimestamp(),
    completedAt: status === 'done' ? FieldValue.serverTimestamp() : null,
  });

  const updatedSnap = await taskRef.get();
  return serializeDoc(updatedSnap);
}

module.exports = {
  listStudents,
  createStudent,
  removeStudent,
  assignTask,
  updateTaskStatus,
};
