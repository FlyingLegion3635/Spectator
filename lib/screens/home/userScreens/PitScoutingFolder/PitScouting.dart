import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spectator/bridge.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/widgets/liquid_glass.dart';

class PitScouting extends StatefulWidget {
  const PitScouting({super.key});

  @override
  State<PitScouting> createState() => _PitScoutingState();
}

class _PitScoutingState extends State<PitScouting> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  final List<TextEditingController> _controllers = List.generate(
    2,
    (i) => TextEditingController(),
  );

  final Map<String, TextEditingController> _customTextControllers = {};
  final Map<String, dynamic> _customValues = {};

  bool _templateLoading = true;
  bool _submitting = false;
  bool _syncingOffline = false;
  int _offlinePendingCount = 0;
  bool _fetchingTeamName = false;
  Timer? _teamNumberDebounce;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
    _refreshOfflineCount();
  }

  @override
  void dispose() {
    _teamNumberDebounce?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final c in _customTextControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTeamNumberChanged(String value) {
    backend.pitInputs[0] = value;
    _teamNumberDebounce?.cancel();
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 2) return;

    // Check offline cache first (instant, no network).
    final cached = backend.getCachedTeamName(digits);
    if (cached != null && cached.isNotEmpty) {
      _controllers[1].text = cached;
      backend.pitInputs[1] = cached;
      return;
    }

    _teamNumberDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _fetchingTeamName = true);
      try {
        final info = await backend.fetchTeamInfoFromBlueAlliance(digits);
        final nickname = info['nickname'] ?? '';
        if (nickname.isNotEmpty && mounted) {
          _controllers[1].text = nickname;
          backend.pitInputs[1] = nickname;
        }
      } catch (_) {
        // Team not found — leave name field as-is.
      } finally {
        if (mounted) setState(() => _fetchingTeamName = false);
      }
    });
  }

  Future<void> _loadTemplate() async {
    setState(() {
      _templateLoading = true;
    });

    await backend.ready;

    try {
      await backend.fetchPitTemplate();
    } catch (_) {
      // Offline — cached pitTemplateFields from _restoreCache still usable.
    }

    for (final field in backend.pitTemplateFields) {
      final key = '${field['key'] ?? ''}'.trim();
      if (key.isEmpty) continue;

      final type = '${field['type'] ?? 'text'}';
      if (type == 'text') {
        _customTextControllers.putIfAbsent(
          key,
          () => TextEditingController(text: '${_customValues[key] ?? ''}'),
        );
      } else if (type == 'checkbox') {
        _customValues.putIfAbsent(key, () => false);
      }
    }

    if (!mounted) return;
    setState(() {
      _templateLoading = false;
    });
  }

  Future<void> _refreshOfflineCount() async {
    final count = await backend.getOfflinePitQueueCount();
    if (!mounted) return;
    setState(() {
      _offlinePendingCount = count;
    });
  }

  Future<void> _openTemplateEditor() async {
    final editableFields =
        (backend.pitTemplateFields.isEmpty
                ? [
                    {
                      'key': 'canClimb',
                      'label': 'Can Climb',
                      'type': 'checkbox',
                      'required': false,
                    },
                    {
                      'key': 'driveTrainType',
                      'label': 'Drive Train Type',
                      'type': 'select',
                      'options': ['Tank', 'Swerve', 'Mecanum', 'Other'],
                      'required': false,
                    },
                  ]
                : backend.pitTemplateFields)
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();

    void addField(String type) {
      if (type == 'separator') {
        editableFields.add({
          'key': '_sep_${editableFields.length}',
          'label': '',
          'type': 'separator',
          'required': false,
        });
        return;
      }
      if (type == 'title') {
        editableFields.add({
          'key': '_title_${editableFields.length}',
          'label': 'Section Title',
          'type': 'title',
          'required': false,
        });
        return;
      }
      final baseLabel = type == 'checkbox'
          ? 'New Checkbox'
          : type == 'select'
          ? 'New Select'
          : 'New Text Field';
      editableFields.add({
        'key': '',
        'label': baseLabel,
        'type': type,
        'options': type == 'select' ? ['Option A', 'Option B'] : [],
        'required': false,
      });
    }

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Pit Template'),
              content: SizedBox(
                width: 760,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              setDialogState(() => addField('text')),
                          icon: const Icon(Icons.text_fields),
                          label: const Text('Add Text'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setDialogState(() => addField('checkbox')),
                          icon: const Icon(Icons.check_box_outlined),
                          label: const Text('Add Checkbox'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setDialogState(() => addField('select')),
                          icon: const Icon(
                            Icons.arrow_drop_down_circle_outlined,
                          ),
                          label: const Text('Add Select'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setDialogState(() => addField('title')),
                          icon: const Icon(Icons.title),
                          label: const Text('Add Title'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setDialogState(() => addField('separator')),
                          icon: const Icon(Icons.horizontal_rule),
                          label: const Text('Add Separator'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 430,
                      child: ListView.builder(
                        itemCount: editableFields.length,
                        itemBuilder: (context, index) {
                          final field = editableFields[index];
                          final type = '${field['type'] ?? 'text'}';
                          final options =
                              (field['options'] as List<dynamic>? ?? [])
                                  .map((entry) => '$entry')
                                  .where((entry) => entry.isNotEmpty)
                                  .toList();

                          // Separator — just a delete button and a visual line
                          if (type == 'separator') {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.horizontal_rule, size: 18),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Divider(),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove separator',
                                      onPressed: () {
                                        setDialogState(() {
                                          editableFields.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Title — label field + delete button only
                          if (type == 'title') {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.title, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            '${field['label'] ?? ''}',
                                        decoration: const InputDecoration(
                                          labelText: 'Section Title',
                                        ),
                                        onChanged: (value) {
                                          field['label'] = value;
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove title',
                                      onPressed: () {
                                        setDialogState(() {
                                          editableFields.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue:
                                              '${field['label'] ?? ''}',
                                          decoration: const InputDecoration(
                                            labelText: 'Label',
                                          ),
                                          onChanged: (value) {
                                            field['label'] = value;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: '${field['key'] ?? ''}',
                                          decoration: const InputDecoration(
                                            labelText: 'Key',
                                            hintText: 'drive_train',
                                          ),
                                          onChanged: (value) {
                                            field['key'] = value;
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove field',
                                        onPressed: () {
                                          setDialogState(() {
                                            editableFields.removeAt(index);
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: type,
                                    decoration: const InputDecoration(
                                      labelText: 'Type',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'text',
                                        child: Text('Text'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'checkbox',
                                        child: Text('Checkbox'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'select',
                                        child: Text('Select'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(() {
                                        field['type'] = value ?? 'text';
                                        if (field['type'] != 'select') {
                                          field['options'] = [];
                                        } else if ((field['options']
                                                    as List<dynamic>? ??
                                                [])
                                            .isEmpty) {
                                          field['options'] = [
                                            'Option A',
                                            'Option B',
                                          ];
                                        }
                                      });
                                    },
                                  ),
                                  GlassCheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Required'),
                                    value: field['required'] == true,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        field['required'] = value ?? false;
                                      });
                                    },
                                  ),
                                  if (type == 'select')
                                    TextFormField(
                                      initialValue: options.join(', '),
                                      decoration: const InputDecoration(
                                        labelText: 'Options (comma separated)',
                                      ),
                                      onChanged: (value) {
                                        field['options'] = value
                                            .split(',')
                                            .map((entry) => entry.trim())
                                            .where((entry) => entry.isNotEmpty)
                                            .toList();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save Template'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) return;

    try {
      final usedKeys = <String>{};
      final fields = <Map<String, dynamic>>[];
      for (final rawField in editableFields) {
        final label = '${rawField['label'] ?? ''}'.trim();
        final key = '${rawField['key'] ?? ''}'.trim();
        final type = '${rawField['type'] ?? 'text'}'.trim();
        final required = rawField['required'] == true;
        final options = (rawField['options'] as List<dynamic>? ?? [])
            .map((entry) => '$entry'.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();

        if (type == 'separator') {
          fields.add({
            'key': '_sep_${fields.length}',
            'label': '',
            'type': 'separator',
            'required': false,
          });
          continue;
        }
        if (type == 'title') {
          if (label.isEmpty) {
            throw Exception('Title sections need a label.');
          }
          fields.add({
            'key': '_title_${fields.length}',
            'label': label,
            'type': 'title',
            'required': false,
          });
          continue;
        }

        if (label.isEmpty || key.isEmpty) {
          throw Exception('Each custom field needs both label and key.');
        }
        if (usedKeys.contains(key)) {
          throw Exception('Template keys must be unique. Duplicate: $key');
        }
        if (type == 'select' && options.isEmpty) {
          throw Exception('Select fields need at least one option.');
        }

        usedKeys.add(key);
        fields.add({
          'label': label,
          'key': key,
          'type': type,
          'required': required,
          if (type == 'select') 'options': options,
        });
      }

      await backend.savePitTemplate(fields);
      await _loadTemplate();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pit template updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      for (int i = 0; i < 2; i++) {
        backend.pitInputs[i] = _controllers[i].text;
      }
      for (int i = 2; i < backend.pitInputs.length; i++) {
        backend.pitInputs[i] = '';
      }

      for (final field in backend.pitTemplateFields) {
        final key = '${field['key'] ?? ''}'.trim();
        if (key.isEmpty) continue;

        final type = '${field['type'] ?? 'text'}';
        if (type == 'text') {
          _customValues[key] = _customTextControllers[key]?.text ?? '';
        }
      }

      backend.customPitResponses = Map<String, dynamic>.from(_customValues);

      final success = await backend.submitPitData(context);

      if (success && backend.pitInputs[0] == '') {
        for (final c in _controllers) {
          c.clear();
        }
        for (final c in _customTextControllers.values) {
          c.clear();
        }
        _customValues.clear();
      }
      await _refreshOfflineCount();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _syncOfflinePitQueue() async {
    if (_syncingOffline) return;
    setState(() {
      _syncingOffline = true;
    });
    try {
      final sent = await backend.syncOfflinePitData();
      await _refreshOfflineCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced $sent offline pit entr${sent == 1 ? 'y' : 'ies'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _syncingOffline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final contentWidth = math.min(
      width - measurements.extraLargePadding,
      760.0,
    );

    return SingleChildScrollView(
      child: Container(
        color: colors.baseColors[4],
        padding: EdgeInsets.only(bottom: measurements.extraLargePadding),
        child: Center(
          child: Column(
            children: [
              SizedBox(height: measurements.largePadding),
              if (backend.canManagePitTemplate)
                Padding(
                  padding: EdgeInsets.only(bottom: measurements.mediumPadding),
                  child: SizedBox(
                    width: contentWidth,
                    child: OutlinedButton.icon(
                      onPressed: _openTemplateEditor,
                      icon: const Icon(Icons.tune),
                      label: const Text('Edit Pit Template'),
                    ),
                  ),
                ),
              _buildTextField(
                contentWidth,
                'Team Number',
                _controllers[0],
                0,
                onChanged: _onTeamNumberChanged,
              ),
              _buildTextField(
                contentWidth,
                'Team Name',
                _controllers[1],
                1,
                suffixWidget: _fetchingTeamName
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              SizedBox(height: measurements.mediumPadding),
              if (_templateLoading)
                const CircularProgressIndicator()
              else
                ...backend.pitTemplateFields.map(
                  (field) => _buildCustomField(contentWidth, field),
                ),
              SizedBox(height: measurements.extraLargePadding),
              SizedBox(
                width: contentWidth,
                height: measurements.clickHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.mainColors[0],
                    foregroundColor: colors.accentColors[0],
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit', style: TextStyle(fontSize: 18)),
                ),
              ),
              SizedBox(height: measurements.mediumPadding),
              SizedBox(
                width: contentWidth,
                height: measurements.clickHeight,
                child: OutlinedButton.icon(
                  onPressed: _offlinePendingCount == 0 || _syncingOffline
                      ? null
                      : _syncOfflinePitQueue,
                  icon: _syncingOffline
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text('Send Offline Pit Data ($_offlinePendingCount)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomField(double width, Map<String, dynamic> field) {
    final key = '${field['key'] ?? ''}'.trim();
    final label = '${field['label'] ?? key}';
    final type = '${field['type'] ?? 'text'}';

    if (type == 'separator') {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: measurements.mediumPadding),
        child: SizedBox(
          width: width,
          child: const Divider(thickness: 1),
        ),
      );
    }

    if (type == 'title') {
      return Padding(
        padding: EdgeInsets.only(
          top: measurements.largePadding,
          bottom: measurements.smallPadding,
        ),
        child: SizedBox(
          width: width,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.baseColors[2],
            ),
          ),
        ),
      );
    }

    if (key.isEmpty) {
      return const SizedBox.shrink();
    }

    if (type == 'checkbox') {
      final checked = (_customValues[key] as bool?) ?? false;
      return SizedBox(
        width: width,
        child: GlassCheckboxListTile(
          title: Text(label, style: TextStyle(color: colors.baseColors[2])),
          value: checked,
          onChanged: (value) {
            setState(() {
              _customValues[key] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      );
    }

    if (type == 'select') {
      final options = (field['options'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList();

      final selected =
          (_customValues[key] as String?) ??
          (options.isNotEmpty ? options.first : '');
      if (selected.isNotEmpty) {
        _customValues[key] = selected;
      }

      return Padding(
        padding: EdgeInsets.only(bottom: measurements.largePadding),
        child: SizedBox(
          width: width,
          child: DropdownButtonFormField<String>(
            value: selected.isEmpty ? null : selected,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: colors.baseColors[0]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.mainColors[2]),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.accentColors[1]),
              ),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (value) {
              setState(() {
                _customValues[key] = value ?? '';
              });
            },
          ),
        ),
      );
    }

    final controller = _customTextControllers.putIfAbsent(
      key,
      () => TextEditingController(text: '${_customValues[key] ?? ''}'),
    );

    return _buildTextField(width, label, controller, -1, customKey: key);
  }

  Widget _buildTextField(
    double width,
    String label,
    TextEditingController controller,
    int index, {
    String? customKey,
    void Function(String)? onChanged,
    Widget? suffixWidget,
  }) {
    return Column(
      children: [
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            onChanged: onChanged ??
                (val) {
                  if (index >= 0) {
                    backend.pitInputs[index] = val;
                  } else if (customKey != null) {
                    _customValues[customKey] = val;
                  }
                },
            style: TextStyle(color: colors.baseColors[2]),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: colors.baseColors[0]),
              suffixIcon: suffixWidget != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: suffixWidget,
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.mainColors[2]),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.accentColors[1]),
              ),
            ),
          ),
        ),
        SizedBox(height: measurements.largePadding),
      ],
    );
  }
}
