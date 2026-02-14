import 'package:flutter/material.dart';
import 'package:spectator/theme/appearance.dart';

Color? parseHexColor(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
    return null;
  }

  return Color(int.parse('FF${normalized.toUpperCase()}', radix: 16));
}

Future<Color?> showColorPickerDialog({
  required BuildContext context,
  required String title,
  required Color initialColor,
}) async {
  return showDialog<Color>(
    context: context,
    builder: (dialogContext) =>
        _ColorPickerDialog(title: title, initialColor: initialColor),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.initialColor});

  final String title;
  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const _presets = <Color>[
    Color(0xFF1242F1),
    Color(0xFF0284C7),
    Color(0xFF0F766E),
    Color(0xFF15803D),
    Color(0xFFEA580C),
    Color(0xFFB91C1C),
    Color(0xFFBE185D),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFF334155),
  ];

  late final TextEditingController _controller;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _controller = TextEditingController(
      text: SettingsModel.toHex(widget.initialColor),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _controller.value = TextEditingValue(
        text: SettingsModel.toHex(color),
        selection: TextSelection.collapsed(
          offset: SettingsModel.toHex(color).length,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _presets)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _selectColor(color),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor.toARGB32() == color.toARGB32()
                              ? Colors.white
                              : Colors.black12,
                          width: _selectedColor.toARGB32() == color.toARGB32()
                              ? 2.2
                              : 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Hex color',
                hintText: '#1242F1',
              ),
              onChanged: (value) {
                final parsed = parseHexColor(value);
                if (parsed == null) return;
                setState(() {
                  _selectedColor = parsed;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 10),
                Text(SettingsModel.toHex(_selectedColor)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
