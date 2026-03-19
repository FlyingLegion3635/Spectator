const { asyncHandler } = require('../utils/asyncHandler');
const {
  listStudents,
  listMembers,
  createStudent,
  approveStudent,
  rejectStudent,
  removeStudent,
  assignTask,
  updateTaskStatus,
} = require('../services/students.service');

const getStudents = asyncHandler(async (req, res) => {
  const students = await listStudents(req.query, req.user);
  res.json({ success: true, students });
});

const getMembers = asyncHandler(async (req, res) => {
  const members = await listMembers(req.query, req.user);
  res.json({ success: true, members });
});

const postStudent = asyncHandler(async (req, res) => {
  const { student, inviteCode } = await createStudent(req.body, req.user);
  res.status(201).json({ success: true, student, inviteCode });
});

const patchApproveStudent = asyncHandler(async (req, res) => {
  const student = await approveStudent(req.params.id, req.user);
  res.json({ success: true, student });
});

const patchRejectStudent = asyncHandler(async (req, res) => {
  const result = await rejectStudent(req.params.id, req.user);
  res.json({ success: true, ...result });
});

const deleteStudent = asyncHandler(async (req, res) => {
  const result = await removeStudent(req.params.id, req.user);
  res.json({ success: true, ...result });
});

const postTask = asyncHandler(async (req, res) => {
  const task = await assignTask(req.body, req.user);
  res.status(201).json({ success: true, task });
});

const patchTaskStatus = asyncHandler(async (req, res) => {
  const task = await updateTaskStatus(req.params.taskId, req.body.status, req.user);
  res.json({ success: true, task });
});

module.exports = {
  getStudents,
  getMembers,
  postStudent,
  patchApproveStudent,
  patchRejectStudent,
  deleteStudent,
  postTask,
  patchTaskStatus,
};
