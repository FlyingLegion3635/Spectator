import 'package:flutter/material.dart';
import 'package:spectator/widgets/liquid_glass.dart';
import 'package:spectator/bridge.dart';
import 'package:spectator/screens/home/color.dart';

class Members extends StatefulWidget {
  const Members({super.key});

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      await backend.fetchMembers();
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

  Future<void> _inviteMember() async {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invite Member'),
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
        await _loadMembers();

        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Invite Key Created'),
              content: SelectableText(
                'Invite key for ${invite['studentName']}:\n\n${invite['inviteCode']}\n\nShare this 6-digit key with the member. They will enter it during signup.',
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

  Future<void> _approveMember(String studentId) async {
    try {
      await backend.approveMember(studentId);
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member approved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  Future<void> _rejectMember(String studentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Member'),
          content: const Text(
            'This will deny the member access and delete their account. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await backend.rejectMember(studentId);
        await _loadMembers();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
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
        await _loadMembers();
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
      await _loadMembers();
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
      await _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  String _roleBadge(String role) {
    switch (role) {
      case 'team_manager':
        return 'Team Manager';
      case 'scout_manager':
        return 'Scout Manager';
      default:
        return 'Scouter';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'invited':
        return Colors.blue;
      case 'active':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: backend.canInviteMembers
          ? FloatingActionButton.extended(
              onPressed: _inviteMember,
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Member'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadMembers,
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
                itemCount: backend.membersData.length,
                itemBuilder: (context, index) {
                  final member = backend.membersData[index];
                  final isMember = member['isMember'] == true;
                  final memberId = '${member['id'] ?? ''}';
                  final studentId = '${member['studentId'] ?? member['id'] ?? ''}';
                  final role = '${member['role'] ?? 'scouter'}';
                  final status = '${member['status'] ?? 'active'}';
                  final displayName = isMember
                      ? '${member['username'] ?? ''}'
                      : '${member['name'] ?? ''}';
                  final cardColor =
                      Theme.of(context).cardTheme.color ?? colors.mainColors[2];
                  final onCard =
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF111827);
                  final onCardMuted = onCard.withValues(alpha: 0.75);
                  final tasks = (member['tasks'] as List<dynamic>? ?? [])
                      .whereType<Map<String, dynamic>>()
                      .toList();

                  final isPending = status == 'pending';
                  final isInvited = status == 'invited';

                  return Card(
                    color: cardColor,
                    margin: EdgeInsets.only(bottom: measurements.mediumPadding),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                color: onCard,
                                fontSize: backend.appSettings[0] + 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _statusColor(status).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _roleBadge(role),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: onCard,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isPending
                            ? 'Awaiting Approval'
                            : isInvited
                            ? 'Invited (key: ${member['inviteCodeDisplay'] ?? ''})'
                            : 'Tasks: ${tasks.length}',
                        style: TextStyle(
                          color: isPending ? Colors.orange : onCardMuted,
                          fontWeight: isPending ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      iconColor: onCard,
                      collapsedIconColor: onCardMuted,
                      textColor: onCard,
                      collapsedTextColor: onCard,
                      children: [
                        // Approve/Reject buttons for pending members
                        if (isPending && backend.canApproveMembers)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _approveMember(studentId),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approve'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _rejectMember(studentId),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Task assignment & remove for active members
                        if (!isPending && !isInvited && backend.canAssignStudentTasks && studentId.isNotEmpty)
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
                              if (backend.isTeamManager && !isMember)
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
                        if (isInvited && backend.isTeamManager)
                          OverflowBar(
                            alignment: MainAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () => _removeStudent(studentId),
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Revoke Invite'),
                                style: TextButton.styleFrom(
                                  foregroundColor: onCard,
                                ),
                              ),
                            ],
                          ),
                        if (tasks.isEmpty && !isPending && !isInvited)
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
                                ? GlassMenuButton<String>(
                                    onSelected: (value) =>
                                        _markTask('${task['id']}', value),
                                    items: const [
                                      GlassMenuItem(
                                        value: 'todo',
                                        label: 'To Do',
                                      ),
                                      GlassMenuItem(
                                        value: 'in_progress',
                                        label: 'In Progress',
                                      ),
                                      GlassMenuItem(
                                        value: 'done',
                                        label: 'Done',
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
