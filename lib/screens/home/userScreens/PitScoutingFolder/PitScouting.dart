import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/home/color.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final c in _customTextControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() {
      _templateLoading = true;
    });

    try {
      await backend.fetchPitTemplate();

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
    } catch (_) {
      // Pit page still works with default fields.
    } finally {
      if (!mounted) return;
      setState(() {
        _templateLoading = false;
      });
    }
  }

  Future<void> _openTemplateEditor() async {
    final initialFields = backend.pitTemplateFields.isEmpty
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
        : backend.pitTemplateFields;

    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(initialFields),
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Pit Template'),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: controller,
              maxLines: 18,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste JSON array of fields',
              ),
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

    if (save != true) {
      controller.dispose();
      return;
    }

    try {
      final decoded = jsonDecode(controller.text);
      if (decoded is! List) {
        throw Exception('Template JSON must be an array of field objects.');
      }

      final fields = decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();

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
    } finally {
      controller.dispose();
    }
  }

  Future<void> _submit() async {
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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final labels = ['Team Number', 'Team Name'];

    return SingleChildScrollView(
      child: Container(
        color: colors.baseColors[4],
        padding: EdgeInsets.only(bottom: measurements.extraLargePadding),
        child: Column(
          children: [
            SizedBox(height: measurements.largePadding),
            if (backend.canManagePitTemplate)
              Padding(
                padding: EdgeInsets.only(bottom: measurements.mediumPadding),
                child: SizedBox(
                  width: width - measurements.extraLargePadding,
                  child: OutlinedButton.icon(
                    onPressed: _openTemplateEditor,
                    icon: const Icon(Icons.tune),
                    label: const Text('Edit Pit Template'),
                  ),
                ),
              ),
            for (int i = 0; i < 2; i++)
              _buildTextField(width, labels[i], _controllers[i], i),
            SizedBox(height: measurements.mediumPadding),
            if (_templateLoading)
              const CircularProgressIndicator()
            else
              ...backend.pitTemplateFields.map(
                (field) => _buildCustomField(width, field),
              ),
            SizedBox(height: measurements.extraLargePadding),
            SizedBox(
              width: width - measurements.extraLargePadding,
              height: measurements.clickHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.mainColors[0],
                  foregroundColor: colors.accentColors[0],
                ),
                onPressed: _submit,
                child: const Text('Submit', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomField(double width, Map<String, dynamic> field) {
    final key = '${field['key'] ?? ''}'.trim();
    final label = '${field['label'] ?? key}';
    final type = '${field['type'] ?? 'text'}';

    if (key.isEmpty) {
      return const SizedBox.shrink();
    }

    if (type == 'checkbox') {
      final checked = (_customValues[key] as bool?) ?? false;
      return SizedBox(
        width: width - measurements.extraLargePadding,
        child: CheckboxListTile(
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
          width: width - measurements.extraLargePadding,
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
  }) {
    return Column(
      children: [
        SizedBox(
          width: width - measurements.extraLargePadding,
          child: TextField(
            controller: controller,
            onChanged: (val) {
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
