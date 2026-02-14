import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/something.dart';
import 'package:spectator/theme/appearance.dart';
import 'package:spectator/widgets/color_picker_dialog.dart';

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _teamInfoLoading = false;
  String _error = '';
  String _teamInfoError = '';
  Map<String, String>? _teamInfo;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({String? teamNumber}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      await backend.fetchAboutProfile(teamNumber: teamNumber);
      final resolvedTeam = '${backend.aboutProfile['teamNumber'] ?? ''}'.trim();
      await _loadTeamInfo(resolvedTeam);
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadTeamInfo(String teamNumber) async {
    if (teamNumber.isEmpty) {
      setState(() {
        _teamInfo = null;
        _teamInfoError = '';
      });
      return;
    }

    setState(() {
      _teamInfoLoading = true;
      _teamInfoError = '';
    });

    try {
      final info = await backend.fetchTeamInfoFromBlueAlliance(teamNumber);
      if (!mounted) return;
      setState(() {
        _teamInfo = info;
        _teamInfoError = '';
        _teamInfoLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _teamInfo = null;
        _teamInfoError = error.toString().replaceFirst('Exception: ', '');
        _teamInfoLoading = false;
      });
    }
  }

  void _insertMarkdown(
    TextEditingController controller, {
    required String before,
    required String after,
    String placeholder = 'text',
  }) {
    final value = controller.value;
    final start = value.selection.start;
    final end = value.selection.end;

    if (start < 0 || end < 0) {
      final updated = '${controller.text}$before$placeholder$after';
      controller.text = updated;
      controller.selection = TextSelection.collapsed(offset: updated.length);
      return;
    }

    final left = controller.text.substring(0, start);
    final selected = controller.text.substring(start, end);
    final right = controller.text.substring(end);
    final usedSelected = selected.isEmpty ? placeholder : selected;
    final replaced = '$left$before$usedSelected$after$right';

    controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(
        offset:
            left.length + before.length + usedSelected.length + after.length,
      ),
    );
  }

  Future<void> _openEditDialog() async {
    final current = backend.aboutProfile;
    final settings = context.read<SettingsModel>();
    final titleController = TextEditingController(
      text: '${current['title'] ?? ''}',
    );
    final missionMarkdownController = TextEditingController(
      text: '${current['missionMarkdown'] ?? current['mission'] ?? ''}',
    );
    final sponsorsController = TextEditingController(
      text: ((current['sponsors'] as List<dynamic>?) ?? []).join(', '),
    );
    final websiteController = TextEditingController(
      text: '${current['website'] ?? ''}',
    );

    final currentTheme = current['uiTheme'] as Map<String, dynamic>? ?? {};
    Color teamPrimaryColor =
        parseHexColor('${currentTheme['primaryColor'] ?? ''}') ??
        settings.teamPrimaryColor ??
        settings.effectivePrimaryColor;
    Color teamAccentColor =
        parseHexColor('${currentTheme['accentColor'] ?? ''}') ??
        settings.teamAccentColor ??
        settings.effectiveAccentColor;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final markdownPreview = missionMarkdownController.text.trim();
            return AlertDialog(
              title: const Text('Edit About Profile'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _input('Title', titleController),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setDialogState(
                              () => _insertMarkdown(
                                missionMarkdownController,
                                before: '## ',
                                after: '\n',
                                placeholder: 'Heading',
                              ),
                            ),
                            tooltip: 'Heading',
                            icon: const Icon(Icons.title),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(
                              () => _insertMarkdown(
                                missionMarkdownController,
                                before: '**',
                                after: '**',
                              ),
                            ),
                            tooltip: 'Bold',
                            icon: const Icon(Icons.format_bold),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(
                              () => _insertMarkdown(
                                missionMarkdownController,
                                before: '*',
                                after: '*',
                              ),
                            ),
                            tooltip: 'Italic',
                            icon: const Icon(Icons.format_italic),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(
                              () => _insertMarkdown(
                                missionMarkdownController,
                                before: '- ',
                                after: '\n',
                                placeholder: 'List item',
                              ),
                            ),
                            tooltip: 'Bullet',
                            icon: const Icon(Icons.format_list_bulleted),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(
                              () => _insertMarkdown(
                                missionMarkdownController,
                                before: '[text](',
                                after: ')',
                                placeholder: 'https://',
                              ),
                            ),
                            tooltip: 'Link',
                            icon: const Icon(Icons.link),
                          ),
                        ],
                      ),
                      _input(
                        'About Us (Markdown)',
                        missionMarkdownController,
                        maxLines: 8,
                      ),
                      if (markdownPreview.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: MarkdownBody(data: markdownPreview),
                        ),
                      _input('Sponsors (comma separated)', sponsorsController),
                      _input('Website', websiteController),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Team UI Colors',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showColorPickerDialog(
                                  context: context,
                                  title: 'Team Primary Color',
                                  initialColor: teamPrimaryColor,
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  teamPrimaryColor = picked;
                                });
                              },
                              icon: Icon(Icons.square, color: teamPrimaryColor),
                              label: const Text('Primary'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showColorPickerDialog(
                                  context: context,
                                  title: 'Team Accent Color',
                                  initialColor: teamAccentColor,
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  teamAccentColor = picked;
                                });
                              },
                              icon: Icon(Icons.square, color: teamAccentColor),
                              label: const Text('Accent'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Primary ${SettingsModel.toHex(teamPrimaryColor)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Accent ${SettingsModel.toHex(teamAccentColor)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save == true) {
      try {
        final missionMarkdown = missionMarkdownController.text.trim();
        final plainMission = missionMarkdown.isNotEmpty
            ? missionMarkdown
                  .replaceAll(RegExp(r'[#>*_`~\[\]\(\)-]'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()
            : '';

        await backend.saveAboutProfile(
          title: titleController.text.trim(),
          mission: plainMission.isNotEmpty ? plainMission : 'Team information',
          missionMarkdown: missionMarkdown,
          sponsors: sponsorsController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          website: websiteController.text.trim(),
          uiTheme: {
            'primaryColor': SettingsModel.toHex(teamPrimaryColor),
            'accentColor': SettingsModel.toHex(teamAccentColor),
          },
          dataVisibility: '${current['dataVisibility'] ?? 'team_only'}',
        );
        await settings.refreshTeamBranding();

        if (!mounted) return;
        setState(() {});
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }

    titleController.dispose();
    missionMarkdownController.dispose();
    sponsorsController.dispose();
    websiteController.dispose();
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = backend.aboutProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? const Color(0xFF111827) : Colors.white;
    final panelBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final headingColor = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF1D4ED8);
    final bodyColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1F2937);
    final sponsors = (profile['sponsors'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();
    final markdown = '${profile['missionMarkdown'] ?? profile['mission'] ?? ''}'
        .trim();
    final viewedTeam = '${profile['teamNumber'] ?? ''}'.trim();
    final ownTeam = '${backend.teamNumber ?? ''}'.trim();
    final canEditViewedTeam = backend.canEditAbout && viewedTeam == ownTeam;

    return Scaffold(
      backgroundColor: colors.baseColors[4],
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: AboutBackgroundPainter(
                brightness: Theme.of(context).brightness,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(measurements.largePadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search team number (e.g. 3635)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => _loadProfile(
                            teamNumber: _searchController.text.trim(),
                          ),
                          child: const Text('Search'),
                        ),
                        if (backend.isAuthenticated &&
                            (backend.teamNumber ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: OutlinedButton(
                              onPressed: () =>
                                  _loadProfile(teamNumber: backend.teamNumber),
                              child: const Text('My Team'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (canEditViewedTeam)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: _openEditDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit About Page'),
                      ),
                    ),
                  if (backend.canEditAbout && !canEditViewedTeam)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        'Viewing another team profile. Switch to "My Team" to edit.',
                      ),
                    ),
                  if (_teamInfoLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(),
                    ),
                  if (_teamInfoError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _teamInfoError,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (_teamInfo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        child: ListTile(
                          leading: (_teamInfo!['logoUrl'] ?? '').isNotEmpty
                              ? Image.network(
                                  _teamInfo!['logoUrl']!,
                                  width: 46,
                                  height: 46,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.shield),
                                )
                              : const Icon(Icons.shield),
                          title: Text(
                            '${_teamInfo!['teamLabel']?.isNotEmpty == true ? _teamInfo!['teamLabel'] : 'Team ${_teamInfo!['teamNumber']}'} - ${_teamInfo!['nickname']}',
                          ),
                          subtitle: Text(
                            '${_teamInfo!['schoolName']}\n${_teamInfo!['city']}, ${_teamInfo!['state']} ${_teamInfo!['country']}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  if (_loading)
                    const CircularProgressIndicator()
                  else if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: const TextStyle(color: Colors.redAccent),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(measurements.largePadding),
                      decoration: BoxDecoration(
                        color: panelColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: panelBorder, width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.08,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${profile['title'] ?? 'ABOUT'}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              color: headingColor,
                            ),
                          ),
                          SizedBox(height: measurements.mediumPadding),
                          if (markdown.isNotEmpty)
                            MarkdownBody(
                              data: markdown,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: bodyColor,
                                ),
                                h2: TextStyle(
                                  color: headingColor,
                                  fontSize: 20,
                                ),
                                listBullet: TextStyle(color: bodyColor),
                                strong: TextStyle(
                                  color: bodyColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                a: TextStyle(
                                  color: headingColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          if (sponsors.isNotEmpty) ...[
                            SizedBox(height: measurements.largePadding),
                            Text(
                              'Sponsors',
                              style: TextStyle(
                                color: headingColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: measurements.smallPadding),
                            for (final sponsor in sponsors)
                              Text(sponsor, style: TextStyle(color: bodyColor)),
                          ],
                          if ('${profile['website'] ?? ''}'.isNotEmpty) ...[
                            SizedBox(height: measurements.mediumPadding),
                            SelectableText(
                              '${profile['website']}',
                              style: TextStyle(
                                color: headingColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutBackgroundPainter extends CustomPainter {
  const AboutBackgroundPainter({required this.brightness});

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final primaryHalo = brightness == Brightness.dark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.22)
        : const Color(0xFF93C5FD).withValues(alpha: 0.36);
    final accentHalo = brightness == Brightness.dark
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
        : const Color(0xFFBFDBFE).withValues(alpha: 0.24);

    paint.color = primaryHalo;
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.5, paint);

    paint.color = accentHalo;
    canvas.drawCircle(Offset(0, size.height), size.width * 0.6, paint);

    paint.color = brightness == Brightness.dark
        ? const Color(0xFF60A5FA).withValues(alpha: 0.35)
        : const Color(0xFF3B82F6).withValues(alpha: 0.35);
    paint.strokeWidth = 2.5;
    paint.style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.2, 0);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.5,
      size.width,
      size.height * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AboutBackgroundPainter oldDelegate) {
    return brightness != oldDelegate.brightness;
  }
}
