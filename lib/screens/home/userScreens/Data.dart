import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:spectator/bridge.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/widgets/liquid_glass.dart';

enum _DataView { pit, match }

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  bool _loading = true;
  String _error = '';
  _DataView _activeView = _DataView.pit;

  Timer? _lookupDebounce;
  bool _teamInfoLoading = false;
  String _teamInfoError = '';
  Map<String, String>? _teamInfo;
  final Map<String, Map<String, String>> _teamDetailsByNumber = {};
  final Set<String> _teamDetailsLoading = {};
  bool _searchAllTeams = true;
  bool _teamDataPublic = false;
  bool _visibilityLoading = false;
  final GlobalKey _exportButtonKey = GlobalKey();

  Color _onColor(Color background, {double alpha = 1.0}) {
    // Use overall opacity to detect translucent glass cards — fall back to
    // the scaffold/theme brightness so text stays readable.
    final bool dark;
    if (background.a < 0.5) {
      // Translucent card (glass theme): derive from scaffold brightness.
      final ctx = _scaffoldContext;
      dark = ctx != null && Theme.of(ctx).brightness == Brightness.dark;
    } else {
      dark = ThemeData.estimateBrightnessForColor(background) ==
          Brightness.dark;
    }
    final base = dark ? Colors.white : const Color(0xFF0F172A);
    return base.withValues(alpha: alpha);
  }

  // Stored in build() so _onColor helpers can reach theme brightness.
  BuildContext? _scaffoldContext;

  String _labelize(String key) {
    const overrides = <String, String>{
      'teamNumber': 'Team Number',
      'teamName': 'Team Name',
      'humanPlayerConfidence': 'Human Player Confidence',
      'driveTrain': 'Drive Train',
      'mainScoringPotential': 'Main Scoring Potential',
      'pointsInAutonomous': 'Points in Autonomous',
      'teleOperatedCapabilities': 'Tele-op Capabilities',
      'datasheetId': 'Datasheet',
      'createdByUsername': 'Created By',
      'createdAt': 'Created At',
      'updatedAt': 'Updated At',
      'matchNumber': 'Match Number',
      'allianceColor': 'Alliance',
      'fireRate': 'Fire Rate',
      'shotsAttempted': 'Shots Attempted',
      'accuracy': 'Accuracy',
      'calculatedPoints': 'Calculated Points',
      'autoClimb': 'Auto Climb',
      'climbLevel': 'Climb Level',
      'scoutedAt': 'Scouted At',
    };
    if (overrides.containsKey(key)) {
      return overrides[key]!;
    }
    final words = key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return words.isEmpty
        ? key
        : words[0].toUpperCase() + words.substring(1).toLowerCase();
  }

  List<Widget> _buildPitDetailTiles(
    Map<String, String> entry,
    Color cardColor,
  ) {
    final detailWidgets = <Widget>[];
    final titleColor = _onColor(cardColor, alpha: 0.88);
    final valueColor = _onColor(cardColor, alpha: 0.74);

    for (final key in entry.keys) {
      if (key == 'id' ||
          key == 'teamNumber' ||
          key == 'teamName' ||
          key == 'version' ||
          key == 'versionCount' ||
          key == 'customResponses') {
        continue;
      }
      final value = '${entry[key] ?? ''}'.trim();
      if (value.isEmpty) continue;
      detailWidgets.add(
        ListTile(
          title: Text(_labelize(key), style: TextStyle(color: titleColor)),
          subtitle: Text(value, style: TextStyle(color: valueColor)),
        ),
      );
    }

    final customRaw = '${entry['customResponses'] ?? ''}'.trim();
    if (customRaw.isNotEmpty && customRaw != '{}') {
      try {
        final parsed = jsonDecode(customRaw);
        if (parsed is Map<String, dynamic> && parsed.isNotEmpty) {
          detailWidgets.add(const Divider());
          detailWidgets.add(
            ListTile(
              title: Text(
                'Custom Pit Responses',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
          parsed.forEach((field, rawValue) {
            final normalized = '$rawValue'.trim();
            final lower = normalized.toLowerCase();
            if (lower == 'true' || lower == 'false') {
              detailWidgets.add(
                GlassCheckboxListTile(
                  value: lower == 'true',
                  onChanged: null,
                  title: Text(
                    _labelize(field),
                    style: TextStyle(color: titleColor),
                  ),
                  checkColor: _onColor(cardColor),
                  activeColor: valueColor,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
              return;
            }

            detailWidgets.add(
              ListTile(
                title: Text(
                  _labelize(field),
                  style: TextStyle(color: titleColor),
                ),
                subtitle: Text(normalized, style: TextStyle(color: valueColor)),
              ),
            );
          });
        }
      } catch (_) {
        detailWidgets.add(
          ListTile(
            title: Text(
              'Custom Responses',
              style: TextStyle(color: titleColor),
            ),
            subtitle: SelectableText(
              customRaw,
              style: TextStyle(color: valueColor, fontFamily: 'monospace'),
            ),
          ),
        );
      }
    }

    return detailWidgets;
  }

  List<Widget> _buildMatchDetailTiles(
    Map<String, String> entry,
    Color cardColor,
  ) {
    final detailWidgets = <Widget>[];
    final titleColor = _onColor(cardColor, alpha: 0.88);
    final valueColor = _onColor(cardColor, alpha: 0.74);

    for (final key in entry.keys) {
      if (key == 'id' ||
          key == 'matchNumber' ||
          key == 'teamNumber' ||
          key == 'allianceColor' ||
          key == 'version' ||
          key == 'versionCount') {
        continue;
      }
      final value = '${entry[key] ?? ''}'.trim();
      if (value.isEmpty) continue;

      if (key == 'autoClimb') {
        final checked = value.toLowerCase() == 'true';
        detailWidgets.add(
          GlassCheckboxListTile(
            value: checked,
            onChanged: null,
            title: Text('Auto Climb', style: TextStyle(color: titleColor)),
            checkColor: _onColor(cardColor),
            activeColor: valueColor,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
        continue;
      }

      detailWidgets.add(
        ListTile(
          title: Text(_labelize(key), style: TextStyle(color: titleColor)),
          subtitle: Text(value, style: TextStyle(color: valueColor)),
        ),
      );
    }

    return detailWidgets;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    await backend.ready;

    try {
      if (backend.isAuthenticated) {
        await backend.fetchDatasheets();
        await _loadDataVisibilityPreference();
      }

      await Future.wait([
        backend.fetchPitEntries(includeAllTeams: _searchAllTeams),
        backend.fetchMatchEntries(includeAllTeams: _searchAllTeams),
      ]);
      await _prefetchVisibleTeamDetails();

      _error = '';
    } catch (error) {
      // Only show error if there's no cached data to display.
      if (backend.scoutingDataList.isEmpty && backend.matchDataList.isEmpty) {
        _error = _errorText(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadDataVisibilityPreference() async {
    if (!backend.isAuthenticated || (backend.teamNumber ?? '').isEmpty) {
      _teamDataPublic = false;
      return;
    }

    await backend.fetchAboutProfile(teamNumber: backend.teamNumber);
    _teamDataPublic =
        '${backend.aboutProfile['dataVisibility'] ?? 'team_only'}' == 'public';
  }

  void _onSearchChanged(String value) {
    setState(() {
      backend.dataSearchInput[0] = value;
    });

    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchEntriesForQuery(value);
      _lookupTeamInfo(value);
    });
  }

  Future<void> _searchEntriesForQuery(String rawInput) async {
    final normalized = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    final teamName = rawInput.trim();

    try {
      if (rawInput.trim().isEmpty) {
        if (backend.isAuthenticated) {
          await Future.wait([
            backend.fetchPitEntries(includeAllTeams: _searchAllTeams),
            backend.fetchMatchEntries(includeAllTeams: _searchAllTeams),
          ]);
        } else {
          backend.scoutingDataList = [];
          backend.matchDataList = [];
        }
      } else if (normalized.isNotEmpty) {
        await Future.wait([
          backend.fetchPitEntries(
            teamNumber: normalized,
            includeAllTeams: _searchAllTeams,
          ),
          backend.fetchMatchEntries(
            teamNumber: normalized,
            includeAllTeams: _searchAllTeams,
          ),
        ]);
      } else {
        await backend.fetchPitEntries(
          teamName: teamName,
          includeAllTeams: _searchAllTeams,
        );
        backend.matchDataList = [];
      }

      await _prefetchVisibleTeamDetails();
      if (!mounted) return;
      setState(() {
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(error);
      });
    }
  }

  Future<void> _openDataVisibilitySettings() async {
    if (!backend.canEditAbout) {
      return;
    }

    bool dialogValue = _teamDataPublic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Team Data Privacy'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Make Team Data Public'),
                    subtitle: const Text(
                      'When enabled, other users can include your team entries in public searches.',
                    ),
                    value: dialogValue,
                    onChanged: (value) {
                      setDialogState(() {
                        dialogValue = value;
                      });
                    },
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _visibilityLoading = true;
    });

    try {
      await backend.fetchAboutProfile(teamNumber: backend.teamNumber);
      final current = backend.aboutProfile;
      await backend.saveAboutProfile(
        title: '${current['title'] ?? ''}',
        mission: '${current['mission'] ?? ''}',
        missionMarkdown:
            '${current['missionMarkdown'] ?? current['mission'] ?? ''}',
        sponsors: (current['sponsors'] as List<dynamic>? ?? [])
            .map((entry) => '$entry')
            .where((entry) => entry.isNotEmpty)
            .toList(),
        website: '${current['website'] ?? ''}',
        dataVisibility: dialogValue ? 'public' : 'team_only',
      );
      if (!mounted) return;
      setState(() {
        _teamDataPublic = dialogValue;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    } finally {
      if (!mounted) return;
      setState(() {
        _visibilityLoading = false;
      });
    }
  }

  Future<void> _prefetchVisibleTeamDetails() async {
    final teamNumbers = <String>{};
    for (final entry in backend.scoutingDataList) {
      final team = '${entry['teamNumber'] ?? ''}'.trim();
      if (team.isNotEmpty) {
        teamNumbers.add(team);
      }
    }
    for (final entry in backend.matchDataList) {
      final team = '${entry['teamNumber'] ?? ''}'.trim();
      if (team.isNotEmpty) {
        teamNumbers.add(team);
      }
    }

    final limited = teamNumbers.take(18).toList();
    for (final teamNumber in limited) {
      if (_teamDetailsByNumber.containsKey(teamNumber) ||
          _teamDetailsLoading.contains(teamNumber)) {
        continue;
      }

      _teamDetailsLoading.add(teamNumber);
      try {
        final details = await backend.fetchTeamInfoFromBlueAlliance(teamNumber);
        _teamDetailsByNumber[teamNumber] = details;
      } catch (_) {
        // Ignore lookup failures and keep rendering raw entry values.
      } finally {
        _teamDetailsLoading.remove(teamNumber);
      }
    }
  }

  Future<void> _lookupTeamInfo(String rawInput) async {
    final normalized = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      if (mounted) {
        setState(() {
          _teamInfo = null;
          _teamInfoError = '';
          _teamInfoLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _teamInfoLoading = true;
        _teamInfoError = '';
      });
    }

    try {
      final info = await backend.fetchTeamInfoFromBlueAlliance(normalized);
      if (mounted) {
        setState(() {
          _teamInfo = info;
          _teamInfoError = '';
          _teamInfoLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _teamInfo = null;
          _teamInfoError = _errorText(error);
          _teamInfoLoading = false;
        });
      }
    }
  }

  Future<void> _createDatasheet() async {
    final seasonController = TextEditingController(
      text: '${DateTime.now().year}',
    );
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Datasheet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: seasonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Season (year)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Datasheet name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await backend.createDatasheet(
          season:
              int.tryParse(seasonController.text.trim()) ?? DateTime.now().year,
          name: nameController.text.trim(),
        );
        await Future.wait([
          backend.fetchPitEntries(includeAllTeams: _searchAllTeams),
          backend.fetchMatchEntries(includeAllTeams: _searchAllTeams),
        ]);
        await _prefetchVisibleTeamDetails();

        if (mounted) {
          setState(() {});
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorText(error))));
        }
      }
    }

    seasonController.dispose();
    nameController.dispose();
  }

  Rect? _exportButtonRect() {
    final box =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  Future<void> _exportCsv() async {
    try {
      final export = await backend.exportSelectedDatasheetCsv();
      if (!mounted) return;

      final downloaded = await backend.downloadCsvFiles(
        pitCsv: export['pitCsv'] ?? '',
        matchCsv: export['matchCsv'] ?? '',
        sharePositionOrigin: _exportButtonRect(),
      );

      if (downloaded) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CSV files downloaded.')));
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('CSV Export'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Text(
                  'Pit CSV\n\n${export['pitCsv']}\n\nMatch CSV\n\n${export['matchCsv']}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _openPitVersionHistory(Map<String, String> entry) async {
    final id = entry['id'] ?? '';
    if (id.isEmpty) return;

    try {
      final versions = await backend.fetchPitEntryVersions(id);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Pit Version History'),
            content: SizedBox(
              width: 620,
              child: versions.isEmpty
                  ? const Text('No history available.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: versions.length,
                      itemBuilder: (itemContext, index) {
                        final item = versions[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              'Version ${item['version']} by ${item['editedByUsername'] ?? 'unknown'}',
                            ),
                            subtitle: Text('${item['editedAt'] ?? ''}'),
                            trailing: backend.canRestoreVersions
                                ? TextButton(
                                    onPressed: () async {
                                      final restored = await backend
                                          .restorePitEntryVersion(
                                            context,
                                            id: id,
                                            version:
                                                int.tryParse(
                                                  '${item['version']}',
                                                ) ??
                                                1,
                                          );

                                      if (restored && mounted) {
                                        Navigator.pop(dialogContext);
                                        setState(() {});
                                      }
                                    },
                                    child: const Text('Restore'),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _openMatchVersionHistory(Map<String, String> entry) async {
    final id = entry['id'] ?? '';
    if (id.isEmpty) return;

    try {
      final versions = await backend.fetchMatchEntryVersions(id);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Match Version History'),
            content: SizedBox(
              width: 620,
              child: versions.isEmpty
                  ? const Text('No history available.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: versions.length,
                      itemBuilder: (itemContext, index) {
                        final item = versions[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              'Version ${item['version']} by ${item['editedByUsername'] ?? 'unknown'}',
                            ),
                            subtitle: Text('${item['editedAt'] ?? ''}'),
                            trailing: backend.canRestoreVersions
                                ? TextButton(
                                    onPressed: () async {
                                      final restored = await backend
                                          .restoreMatchEntryVersion(
                                            context,
                                            id: id,
                                            version:
                                                int.tryParse(
                                                  '${item['version']}',
                                                ) ??
                                                1,
                                          );

                                      if (restored && mounted) {
                                        Navigator.pop(dialogContext);
                                        setState(() {});
                                      }
                                    },
                                    child: const Text('Restore'),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _openPitEditDialog(Map<String, String> entry) async {
    final id = entry['id'] ?? '';
    if (id.isEmpty) return;

    // Parse existing customResponses from the entry.
    Map<String, dynamic> existingCustom = {};
    try {
      final raw = entry['customResponses'] ?? '{}';
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        existingCustom = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    // Fixed fields — always present.
    final fixedControllers = <String, TextEditingController>{
      'teamNumber': TextEditingController(text: entry['teamNumber'] ?? ''),
      'teamName': TextEditingController(text: entry['teamName'] ?? ''),
      'humanPlayerConfidence': TextEditingController(
        text: entry['humanPlayerConfidence'] ?? '',
      ),
      'driveTrain': TextEditingController(text: entry['driveTrain'] ?? ''),
      'mainScoringPotential': TextEditingController(
        text: entry['mainScoringPotential'] ?? '',
      ),
      'pointsInAutonomous': TextEditingController(
        text: entry['pointsInAutonomous'] ?? '',
      ),
      'teleOperatedCapabilities': TextEditingController(
        text: entry['teleOperatedCapabilities'] ?? '',
      ),
    };

    // Build controllers/values for template custom fields.
    final customTextControllers = <String, TextEditingController>{};
    final customValues = <String, dynamic>{};

    for (final field in backend.pitTemplateFields) {
      final key = '${field['key'] ?? ''}'.trim();
      final type = '${field['type'] ?? 'text'}';
      if (key.isEmpty || type == 'separator' || type == 'title') continue;

      if (type == 'text') {
        customTextControllers[key] = TextEditingController(
          text: '${existingCustom[key] ?? ''}',
        );
      } else if (type == 'checkbox') {
        final val = existingCustom[key];
        customValues[key] = val == true || val == 'true';
      } else if (type == 'select') {
        customValues[key] = '${existingCustom[key] ?? ''}';
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final templateWidgets = <Widget>[];
            for (final field in backend.pitTemplateFields) {
              final key = '${field['key'] ?? ''}'.trim();
              final label = '${field['label'] ?? key}';
              final type = '${field['type'] ?? 'text'}';

              if (type == 'separator') {
                templateWidgets.add(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(thickness: 1),
                  ),
                );
                continue;
              }
              if (type == 'title') {
                templateWidgets.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
                continue;
              }
              if (key.isEmpty) continue;

              if (type == 'checkbox') {
                templateWidgets.add(
                  GlassCheckboxListTile(
                    title: Text(label),
                    value: (customValues[key] as bool?) ?? false,
                    onChanged: (v) {
                      setDialogState(() => customValues[key] = v ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                );
              } else if (type == 'select') {
                final options = (field['options'] as List<dynamic>? ?? [])
                    .map((e) => '$e')
                    .where((e) => e.isNotEmpty)
                    .toList();
                final current = '${customValues[key] ?? ''}';
                final effectiveValue =
                    options.contains(current) ? current : null;

                templateWidgets.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: effectiveValue,
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                      ),
                      items: options
                          .map(
                            (o) =>
                                DropdownMenuItem(value: o, child: Text(o)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() => customValues[key] = v ?? '');
                      },
                    ),
                  ),
                );
              } else {
                templateWidgets.add(
                  _field(label, customTextControllers[key]!),
                );
              }
            }

            return AlertDialog(
              title: const Text('Edit Pit Entry'),
              content: SizedBox(
                width: screenWidth > 600 ? 520 : screenWidth * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Team Number', fixedControllers['teamNumber']!),
                      _field('Team Name', fixedControllers['teamName']!),
                      _field(
                        'Human Player Confidence',
                        fixedControllers['humanPlayerConfidence']!,
                      ),
                      _field('Drive Train', fixedControllers['driveTrain']!),
                      _field(
                        'Main Scoring Potential',
                        fixedControllers['mainScoringPotential']!,
                      ),
                      _field(
                        'Points in Autonomous',
                        fixedControllers['pointsInAutonomous']!,
                      ),
                      _field(
                        'Tele-operated Capabilities',
                        fixedControllers['teleOperatedCapabilities']!,
                      ),
                      if (templateWidgets.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(thickness: 2),
                        ),
                        ...templateWidgets,
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // Collect values before disposing anything.
    final updated = <String, String>{};
    for (final e in fixedControllers.entries) {
      updated[e.key] = e.value.text;
    }

    final customResponses = <String, dynamic>{};
    for (final field in backend.pitTemplateFields) {
      final key = '${field['key'] ?? ''}'.trim();
      final type = '${field['type'] ?? 'text'}';
      if (key.isEmpty || type == 'separator' || type == 'title') continue;

      if (type == 'text') {
        customResponses[key] = customTextControllers[key]?.text ?? '';
      } else {
        customResponses[key] = customValues[key] ?? '';
      }
    }
    updated['customResponses'] = jsonEncode(customResponses);

    // Now dispose all controllers.
    for (final c in fixedControllers.values) {
      c.dispose();
    }
    for (final c in customTextControllers.values) {
      c.dispose();
    }

    if (confirmed != true) return;

    final success = await backend.updatePitEntry(
      context,
      id: id,
      updated: updated,
    );

    if (success && mounted) {
      setState(() {});
    }
  }

  Future<void> _openMatchEditDialog(Map<String, String> entry) async {
    final id = entry['id'] ?? '';
    if (id.isEmpty) return;

    final matchNumberController = TextEditingController(
      text: entry['matchNumber'] ?? '',
    );
    final teamNumberController = TextEditingController(
      text: entry['teamNumber'] ?? '',
    );
    final fireRateController = TextEditingController(
      text: entry['fireRate'] ?? '0',
    );
    final shotsController = TextEditingController(
      text: entry['shotsAttempted'] ?? '0',
    );
    final accuracyController = TextEditingController(
      text: entry['accuracy'] ?? '0',
    );
    final pointsController = TextEditingController(
      text: entry['calculatedPoints'] ?? '0',
    );
    String allianceColor = (entry['allianceColor'] == 'Blue') ? 'Blue' : 'Red';
    String climbLevel = _safeClimbLevel(entry['climbLevel']);
    bool autoClimb = (entry['autoClimb'] ?? '').toLowerCase() == 'true';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Match Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field('Match Number', matchNumberController),
                    _field('Team Number', teamNumberController),
                    DropdownButtonFormField<String>(
                      initialValue: allianceColor,
                      decoration: const InputDecoration(
                        labelText: 'Alliance Color',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Red', child: Text('Red')),
                        DropdownMenuItem(value: 'Blue', child: Text('Blue')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          allianceColor = value ?? 'Red';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _field('Fire Rate', fireRateController),
                    _field('Shots Attempted', shotsController),
                    _field('Accuracy (0.0 - 1.0)', accuracyController),
                    _field('Calculated Points', pointsController),
                    const SizedBox(height: 10),
                    GlassSwitchListTile(
                      value: autoClimb,
                      title: const Text('Auto Climb'),
                      onChanged: (value) {
                        setDialogState(() {
                          autoClimb = value;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: climbLevel,
                      decoration: const InputDecoration(
                        labelText: 'Climb Level',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('None')),
                        DropdownMenuItem(value: 'L1', child: Text('L1')),
                        DropdownMenuItem(value: 'L2', child: Text('L2')),
                        DropdownMenuItem(value: 'L3', child: Text('L3')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          climbLevel = _safeClimbLevel(value);
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      matchNumberController.dispose();
      teamNumberController.dispose();
      fireRateController.dispose();
      shotsController.dispose();
      accuracyController.dispose();
      pointsController.dispose();
      return;
    }

    final updated = {
      'matchNumber': matchNumberController.text,
      'teamNumber': teamNumberController.text,
      'allianceColor': allianceColor,
      'fireRate': _safeDouble(fireRateController.text),
      'shotsAttempted': _safeInt(shotsController.text),
      'accuracy': _safeAccuracy(accuracyController.text),
      'calculatedPoints': _safeInt(pointsController.text),
      'autoClimb': autoClimb,
      'climbLevel': climbLevel,
      'scoutedAt': entry['scoutedAt'] ?? DateTime.now().toUtc().toIso8601String(),
    };

    final success = await backend.updateMatchEntry(
      context,
      id: id,
      updated: updated,
    );

    matchNumberController.dispose();
    teamNumberController.dispose();
    fireRateController.dispose();
    shotsController.dispose();
    accuracyController.dispose();
    pointsController.dispose();

    if (success && mounted) {
      setState(() {});
    }
  }

  String _safeClimbLevel(String? value) {
    if (value == 'L1' || value == 'L2' || value == 'L3') {
      return value!;
    }
    return 'None';
  }

  int _safeInt(String raw) => int.tryParse(raw.trim()) ?? 0;

  double _safeDouble(String raw) => double.tryParse(raw.trim()) ?? 0;

  double _safeAccuracy(String raw) {
    final value = double.tryParse(raw.trim()) ?? 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.replaceFirst('Exception: ', '')
        : text;
  }

  List<Map<String, String>> _relatedMatchesForTeam(String teamNumber) {
    return backend.matchDataList
        .where((entry) => '${entry['teamNumber'] ?? ''}' == teamNumber)
        .toList()
      ..sort((a, b) {
        final left = int.tryParse('${a['matchNumber'] ?? ''}') ?? 0;
        final right = int.tryParse('${b['matchNumber'] ?? ''}') ?? 0;
        return left.compareTo(right);
      });
  }

  Widget _buildMatchGroupedList(List<Map<String, String>> entries) {
    if (entries.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: measurements.extraLargePadding),
          Center(
            child: Text(
              'No data found',
              style: TextStyle(color: colors.baseColors[1]),
            ),
          ),
        ],
      );
    }

    // Group entries by team number, preserving sorted order.
    final Map<String, List<Map<String, String>>> byTeam = {};
    for (final entry in entries) {
      final team = '${entry['teamNumber'] ?? ''}';
      byTeam.putIfAbsent(team, () => []).add(entry);
    }
    // Sort each team's matches by match number.
    for (final matches in byTeam.values) {
      matches.sort((a, b) {
        final left = int.tryParse('${a['matchNumber'] ?? ''}') ?? 0;
        final right = int.tryParse('${b['matchNumber'] ?? ''}') ?? 0;
        return left.compareTo(right);
      });
    }
    final sortedTeams = byTeam.keys.toList()
      ..sort(
        (a, b) =>
            (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
      );

    return ListView.builder(
      itemCount: sortedTeams.length,
      itemBuilder: (context, index) {
        final teamNumber = sortedTeams[index];
        final teamMatches = byTeam[teamNumber]!;
        final teamDetails = _teamDetailsByNumber[teamNumber];
        final cardColor =
            Theme.of(context).cardTheme.color ?? colors.mainColors[2];
        final titleColor = _onColor(cardColor);
        final subtitleColor = _onColor(cardColor, alpha: 0.74);

        final teamLabel =
            teamDetails != null &&
                (teamDetails['teamLabel'] ?? '').isNotEmpty
            ? '${teamDetails['teamLabel']} - ${teamDetails['nickname'] ?? ''}'
            : teamDetails != null
            ? 'Team $teamNumber - ${teamDetails['nickname'] ?? ''}'
            : 'Team $teamNumber';

        return Card(
          color: cardColor,
          margin: EdgeInsets.symmetric(
            horizontal: measurements.largePadding,
            vertical: 5,
          ),
          child: ExpansionTile(
            leading:
                teamDetails != null &&
                    (teamDetails['logoUrl'] ?? '').isNotEmpty
                ? Image.network(
                    teamDetails['logoUrl']!,
                    width: 36,
                    height: 36,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.groups),
                  )
                : const Icon(Icons.groups),
            title: Text(teamLabel, style: TextStyle(color: titleColor)),
            subtitle: Text(
              '${teamMatches.length} match${teamMatches.length == 1 ? '' : 'es'}',
              style: TextStyle(color: subtitleColor),
            ),
            children: [
              for (final entry in teamMatches)
                _buildMatchEntryTile(entry, cardColor, titleColor, subtitleColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchEntryTile(
    Map<String, String> entry,
    Color cardColor,
    Color titleColor,
    Color subtitleColor,
  ) {
    final version = entry['version'] ?? '1';
    final versionCount = entry['versionCount'] ?? '0';
    return Card(
      color: cardColor.withValues(alpha: 0.6),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Text(
          'Match ${entry['matchNumber']} — ${entry['allianceColor']} Alliance',
          style: TextStyle(color: titleColor, fontSize: 14),
        ),
        subtitle: Text(
          'Points: ${entry['calculatedPoints']} | Shots: ${entry['shotsAttempted']} | Acc: ${entry['accuracy']}  (v$version, rev: $versionCount)',
          style: TextStyle(color: subtitleColor, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.history, size: 20),
              onPressed: () => _openMatchVersionHistory(entry),
            ),
            if (backend.canMakeRevisions)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _openMatchEditDialog(entry),
              ),
          ],
        ),
        children: _buildMatchDetailTiles(entry, cardColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scaffoldContext = context;
    final filteredPitEntries = backend.getFilteredData();
    final filteredMatchEntries = backend.getFilteredMatchData();
    final Map<String, String>? resolvedTeamInfo = _teamInfo;

    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: measurements.largePadding),
          if (backend.isAuthenticated)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: measurements.largePadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'datasheet-${backend.selectedDatasheetId ?? ''}',
                      ),
                      initialValue: backend.selectedDatasheetId,
                      decoration: const InputDecoration(
                        labelText: 'Season Datasheet',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final sheet in backend.datasheets)
                          DropdownMenuItem(
                            value: '${sheet['id']}',
                            child: Text(
                              '${sheet['season']} - ${sheet['name']}',
                            ),
                          ),
                      ],
                      onChanged: (value) async {
                        backend.selectedDatasheetId = value;
                        await Future.wait([
                          backend.fetchPitEntries(
                            includeAllTeams: _searchAllTeams,
                          ),
                          backend.fetchMatchEntries(
                            includeAllTeams: _searchAllTeams,
                          ),
                        ]);
                        await _prefetchVisibleTeamDetails();
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  if (backend.canCreateDatasheet) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _createDatasheet,
                      icon: const Icon(Icons.add_box),
                      tooltip: 'Create Datasheet',
                    ),
                  ],
                  if (backend.canExportData) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: _exportButtonKey,
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.download),
                      tooltip: 'Export CSV',
                    ),
                  ],
                  if (backend.canEditAbout) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _visibilityLoading
                          ? null
                          : _openDataVisibilitySettings,
                      icon: const Icon(Icons.settings),
                      tooltip: 'Data Privacy Settings',
                    ),
                  ],
                ],
              ),
            ),
          if (_visibilityLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: LinearProgressIndicator(),
            ),
          SizedBox(height: measurements.mediumPadding),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: measurements.largePadding,
            ),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Pit Data'),
                  selected: _activeView == _DataView.pit,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _activeView = _DataView.pit;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Match Data'),
                  selected: _activeView == _DataView.match,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _activeView = _DataView.match;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          if (backend.isAuthenticated)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: measurements.largePadding,
              ),
              child: GlassSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Search Public Team Data'),
                subtitle: Text(
                  _searchAllTeams
                      ? 'Showing your data plus teams that marked data as public.'
                      : 'Showing only data collected by your team.',
                ),
                value: _searchAllTeams,
                onChanged: (value) async {
                  setState(() {
                    _searchAllTeams = value;
                  });
                  await _searchEntriesForQuery(backend.dataSearchInput[0]);
                },
              ),
            ),
          SizedBox(height: measurements.mediumPadding),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: measurements.largePadding,
            ),
            child: TextField(
              style: TextStyle(color: colors.baseColors[2]),
              decoration: InputDecoration(
                hintText: _searchAllTeams
                    ? 'Search public data by team number, team name, or match number...'
                    : 'Search your team data by team number, team name, or match number...',
                hintStyle: TextStyle(color: colors.baseColors[1]),
                prefixIcon: Icon(Icons.search, color: colors.accentColors[0]),
                filled: true,
                fillColor: colors.mainColors[2],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_teamInfoLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12.0),
              child: CircularProgressIndicator(),
            ),
          if (_teamInfoError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Text(
                _teamInfoError,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (resolvedTeamInfo != null)
            Padding(
              padding: EdgeInsets.only(
                top: 10,
                left: measurements.largePadding,
                right: measurements.largePadding,
              ),
              child: Card(
                color:
                    Theme.of(context).cardTheme.color ?? colors.mainColors[2],
                child: ListTile(
                  textColor: Theme.of(context).colorScheme.onSurface,
                  leading: (resolvedTeamInfo['logoUrl'] ?? '').isNotEmpty
                      ? Image.network(
                          resolvedTeamInfo['logoUrl']!,
                          width: 48,
                          height: 48,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.shield, color: colors.accentColors[0]),
                        )
                      : Icon(Icons.shield, color: colors.accentColors[0]),
                  title: Text(
                    '${resolvedTeamInfo['teamLabel']?.isNotEmpty == true ? resolvedTeamInfo['teamLabel'] : 'Team ${resolvedTeamInfo['teamNumber']}'} - ${resolvedTeamInfo['nickname']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${resolvedTeamInfo['schoolName']}\n${resolvedTeamInfo['city']}, ${resolvedTeamInfo['state']} ${resolvedTeamInfo['country']}\nDistrict: ${resolvedTeamInfo['districtLabel']}\nRookie: ${resolvedTeamInfo['rookieYear']}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          SizedBox(height: measurements.largePadding),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
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
                  : _activeView == _DataView.pit
                  ? (filteredPitEntries.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: measurements.extraLargePadding),
                            Center(
                              child: Text(
                                'No data found',
                                style: TextStyle(color: colors.baseColors[1]),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: filteredPitEntries.length,
                          itemBuilder: (itemContext, index) {
                            final entry = filteredPitEntries[index];
                            final version = entry['version'] ?? '1';
                            final versionCount = entry['versionCount'] ?? '0';
                            final teamNumber =
                                '${entry['teamNumber'] ?? ''}';
                            final teamDetails =
                                _teamDetailsByNumber[teamNumber];
                            final relatedMatches =
                                _relatedMatchesForTeam(teamNumber);
                            final cardColor =
                                Theme.of(context).cardTheme.color ??
                                colors.mainColors[2];
                            final titleColor = _onColor(cardColor);
                            final subtitleColor =
                                _onColor(cardColor, alpha: 0.74);

                            return Card(
                              color: cardColor,
                              margin: EdgeInsets.symmetric(
                                horizontal: measurements.largePadding,
                                vertical: 5,
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  teamDetails == null
                                      ? 'Team $teamNumber'
                                      : '${teamDetails['teamLabel']?.isNotEmpty == true ? teamDetails['teamLabel'] : 'Team $teamNumber'} - ${teamDetails['nickname'] ?? ''}',
                                  style: TextStyle(color: titleColor),
                                ),
                                subtitle: Text(
                                  '${entry['teamName']} (v$version, revisions: $versionCount)',
                                  style: TextStyle(color: subtitleColor),
                                ),
                                leading:
                                    teamDetails != null &&
                                        (teamDetails['logoUrl'] ?? '')
                                            .isNotEmpty
                                    ? Image.network(
                                        teamDetails['logoUrl']!,
                                        width: 36,
                                        height: 36,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.shield),
                                      )
                                    : const Icon(Icons.shield),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.history),
                                      onPressed: () =>
                                          _openPitVersionHistory(entry),
                                    ),
                                    if (backend.canMakeRevisions)
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () =>
                                            _openPitEditDialog(entry),
                                      ),
                                  ],
                                ),
                                children: [
                                  if (relatedMatches.isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 6.0,
                                          ),
                                          child: Text(
                                            'Related Match Data',
                                            style: TextStyle(
                                              color: titleColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        for (final match in relatedMatches)
                                          ListTile(
                                            dense: true,
                                            title: Text(
                                              'Match ${match['matchNumber']} (${match['allianceColor']})',
                                              style:
                                                  TextStyle(color: titleColor),
                                            ),
                                            subtitle: Text(
                                              'Points: ${match['calculatedPoints']} | Accuracy: ${match['accuracy']} | Shots: ${match['shotsAttempted']}',
                                              style: TextStyle(
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ),
                                        const Divider(),
                                      ],
                                    ),
                                  ..._buildPitDetailTiles(entry, cardColor),
                                ],
                              ),
                            );
                          },
                        ))
                  : _buildMatchGroupedList(filteredMatchEntries),
            ),
          ),
        ],
      ),
    );
  }
}
