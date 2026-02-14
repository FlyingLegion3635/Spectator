import 'package:flutter/material.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/home/color.dart';

class Students extends StatefulWidget {
  const Students({super.key});

  @override
  State<Students> createState() => _StudentsState();
}

class _StudentsState extends State<Students> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      await backend.fetchStudents();
      _error = '';
    } catch (error) {
      _error = _errorText(error);
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.replaceFirst('Exception: ', '')
        : text;
  }

  Future<void> _inviteStudent() async {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invite Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Invite'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final invite = await backend.inviteStudent(
          name: nameController.text.trim(),
          username: usernameController.text.trim(),
          email: emailController.text.trim(),
        );
        await _loadStudents();

        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Student Invite Created'),
              content: SelectableText(
                'Invite code for ${invite['studentName']}:\n\n${invite['inviteCode']}\n\nShare this once with the student.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }

    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
  }

  Future<void> _assignTask(String studentId) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await backend.assignStudentTask(
          studentId: studentId,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
        );
        await _loadStudents();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _removeStudent(String studentId) async {
    try {
      await backend.removeStudent(studentId);
      await _loadStudents();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  Future<void> _markTask(String taskId, String status) async {
    try {
      await backend.markStudentTaskStatus(taskId: taskId, status: status);
      await _loadStudents();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.baseColors[4],
      floatingActionButton: backend.canInviteStudents
          ? FloatingActionButton.extended(
              onPressed: _inviteStudent,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Student'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadStudents,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error.isNotEmpty
            ? ListView(
                children: [
                  SizedBox(height: measurements.extraLargePadding),
                  Padding(
                    padding: EdgeInsets.all(measurements.largePadding),
                    child: Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: EdgeInsets.all(measurements.largePadding),
                itemCount: backend.studentsData.length,
                itemBuilder: (context, index) {
                  final student = backend.studentsData[index];
                  final studentId = '${student['id'] ?? ''}';
                  final role = '${student['role'] ?? 'scouter'}';
                  final cardColor =
                      Theme.of(context).cardTheme.color ?? colors.mainColors[2];
                  final onCard =
                      ThemeData.estimateBrightnessForColor(cardColor) ==
                          Brightness.dark
                      ? Colors.white
                      : const Color(0xFF111827);
                  final onCardMuted = onCard.withValues(alpha: 0.75);
                  final tasks = (student['tasks'] as List<dynamic>? ?? [])
                      .whereType<Map<String, dynamic>>()
                      .toList();

                  return Card(
                    color: cardColor,
                    margin: EdgeInsets.only(bottom: measurements.mediumPadding),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        '${student['name']} ($role)',
                        style: TextStyle(
                          color: onCard,
                          fontSize: backend.appSettings[0] + 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Tasks: ${tasks.length} | Status: ${student['status'] ?? 'active'}',
                        style: TextStyle(color: onCardMuted),
                      ),
                      iconColor: onCard,
                      collapsedIconColor: onCardMuted,
                      textColor: onCard,
                      collapsedTextColor: onCard,
                      children: [
                        if ('${student['inviteCodeLast6'] ?? ''}'.isNotEmpty &&
                            '${student['status'] ?? ''}' == 'invited')
                          ListTile(
                            title: Text(
                              'Invite Suffix: ${student['inviteCodeLast6']}',
                              style: TextStyle(color: onCard),
                            ),
                            subtitle: Text(
                              'Student must use the full 64-char invite code to sign up.',
                              style: TextStyle(color: onCardMuted),
                            ),
                          ),
                        if (backend.canAssignStudentTasks)
                          OverflowBar(
                            alignment: MainAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () => _assignTask(studentId),
                                icon: const Icon(Icons.playlist_add),
                                label: const Text('Assign Task'),
                                style: TextButton.styleFrom(
                                  foregroundColor: onCard,
                                ),
                              ),
                              if (backend.canInviteStudents)
                                TextButton.icon(
                                  onPressed: () => _removeStudent(studentId),
                                  icon: const Icon(Icons.delete_forever),
                                  label: const Text('Remove'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: onCard,
                                  ),
                                ),
                            ],
                          ),
                        if (tasks.isEmpty)
                          ListTile(
                            title: Text(
                              'No tasks assigned yet.',
                              style: TextStyle(color: onCard),
                            ),
                          ),
                        for (final task in tasks)
                          ListTile(
                            title: Text(
                              '${task['title'] ?? ''}',
                              style: TextStyle(color: onCard),
                            ),
                            subtitle: Text(
                              '${task['description'] ?? ''}\nStatus: ${task['status'] ?? 'todo'}',
                              style: TextStyle(color: onCardMuted),
                            ),
                            isThreeLine: true,
                            trailing: backend.canMarkStudentTasks
                                ? PopupMenuButton<String>(
                                    onSelected: (value) =>
                                        _markTask('${task['id']}', value),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'todo',
                                        child: Text('To Do'),
                                      ),
                                      PopupMenuItem(
                                        value: 'in_progress',
                                        child: Text('In Progress'),
                                      ),
                                      PopupMenuItem(
                                        value: 'done',
                                        child: Text('Done'),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
