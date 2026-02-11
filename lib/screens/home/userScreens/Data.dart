import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/home/color.dart';

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

    try {
      if (backend.isAuthenticated) {
        await backend.fetchDatasheets();
      }

      await Future.wait([
        backend.fetchPitEntries(),
        backend.fetchMatchEntries(),
      ]);
      await _prefetchVisibleTeamDetails();

      _error = '';
    } catch (error) {
      _error = _errorText(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
            backend.fetchPitEntries(),
            backend.fetchMatchEntries(),
          ]);
        } else {
          backend.scoutingDataList = [];
          backend.matchDataList = [];
        }
      } else if (normalized.isNotEmpty) {
        await Future.wait([
          backend.fetchPitEntries(teamNumber: normalized),
          backend.fetchMatchEntries(teamNumber: normalized),
        ]);
      } else {
        await backend.fetchPitEntries(teamName: teamName);
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
          backend.fetchPitEntries(),
          backend.fetchMatchEntries(),
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

  Future<void> _exportCsv() async {
    try {
      final export = await backend.exportSelectedDatasheetCsv();
      if (!mounted) return;

      final downloaded = await backend.downloadCsvFiles(
        pitCsv: export['pitCsv'] ?? '',
        matchCsv: export['matchCsv'] ?? '',
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

    final teamNumberController = TextEditingController(
      text: entry['teamNumber'] ?? '',
    );
    final teamNameController = TextEditingController(
      text: entry['teamName'] ?? '',
    );
    final hpController = TextEditingController(
      text: entry['humanPlayerConfidence'] ?? '',
    );
    final driveController = TextEditingController(
      text: entry['driveTrain'] ?? '',
    );
    final scoringController = TextEditingController(
      text: entry['mainScoringPotential'] ?? '',
    );
    final autoController = TextEditingController(
      text: entry['pointsInAutonomous'] ?? '',
    );
    final teleopController = TextEditingController(
      text: entry['teleOperatedCapabilities'] ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Pit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Team Number', teamNumberController),
                _field('Team Name', teamNameController),
                _field('Human Player Confidence', hpController),
                _field('Drive Train', driveController),
                _field('Main Scoring Potential', scoringController),
                _field('Points in Autonomous', autoController),
                _field('Tele-operated Capabilities', teleopController),
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

    if (confirmed != true) {
      teamNumberController.dispose();
      teamNameController.dispose();
      hpController.dispose();
      driveController.dispose();
      scoringController.dispose();
      autoController.dispose();
      teleopController.dispose();
      return;
    }

    final updated = {
      'teamNumber': teamNumberController.text,
      'teamName': teamNameController.text,
      'humanPlayerConfidence': hpController.text,
      'driveTrain': driveController.text,
      'mainScoringPotential': scoringController.text,
      'pointsInAutonomous': autoController.text,
      'teleOperatedCapabilities': teleopController.text,
    };

    final success = await backend.updatePitEntry(
      context,
      id: id,
      updated: updated,
    );

    teamNumberController.dispose();
    teamNameController.dispose();
    hpController.dispose();
    driveController.dispose();
    scoringController.dispose();
    autoController.dispose();
    teleopController.dispose();

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
                    SwitchListTile(
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
      'scoutedAt': entry['scoutedAt'] ?? DateTime.now().toIso8601String(),
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

  @override
  Widget build(BuildContext context) {
    final filteredPitEntries = backend.getFilteredData();
    final filteredMatchEntries = backend.getFilteredMatchData();
    final activeEntries = _activeView == _DataView.pit
        ? filteredPitEntries
        : filteredMatchEntries;

    return Scaffold(
      backgroundColor: colors.baseColors[4],
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
                          backend.fetchPitEntries(),
                          backend.fetchMatchEntries(),
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
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.download),
                      tooltip: 'Export CSV',
                    ),
                  ],
                ],
              ),
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
          SizedBox(height: measurements.mediumPadding),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: measurements.largePadding,
            ),
            child: TextField(
              style: TextStyle(color: colors.baseColors[2]),
              decoration: InputDecoration(
                hintText:
                    'Search by team number, team name, or match number...',
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
          if (_teamInfo != null)
            Padding(
              padding: EdgeInsets.only(
                top: 10,
                left: measurements.largePadding,
                right: measurements.largePadding,
              ),
              child: Card(
                color: colors.mainColors[2],
                child: ListTile(
                  leading: (_teamInfo!['logoUrl'] ?? '').isNotEmpty
                      ? Image.network(
                          _teamInfo!['logoUrl']!,
                          width: 48,
                          height: 48,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.shield, color: colors.accentColors[0]),
                        )
                      : Icon(Icons.shield, color: colors.accentColors[0]),
                  title: Text(
                    '${_teamInfo!['teamLabel']?.isNotEmpty == true ? _teamInfo!['teamLabel'] : 'Team ${_teamInfo!['teamNumber']}'} - ${_teamInfo!['nickname']}',
                    style: TextStyle(color: colors.accentColors[0]),
                  ),
                  subtitle: Text(
                    '${_teamInfo!['schoolName']}\n${_teamInfo!['city']}, ${_teamInfo!['state']} ${_teamInfo!['country']}\nDistrict: ${_teamInfo!['districtLabel']}\nRookie: ${_teamInfo!['rookieYear']}',
                    style: TextStyle(color: colors.baseColors[1]),
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
                  : activeEntries.isEmpty
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
                      itemCount: activeEntries.length,
                      itemBuilder: (itemContext, index) {
                        final entry = activeEntries[index];
                        final version = entry['version'] ?? '1';
                        final versionCount = entry['versionCount'] ?? '0';

                        if (_activeView == _DataView.pit) {
                          final teamNumber = '${entry['teamNumber'] ?? ''}';
                          final teamDetails = _teamDetailsByNumber[teamNumber];
                          final relatedMatches = _relatedMatchesForTeam(
                            teamNumber,
                          );

                          return Card(
                            color: colors.mainColors[2],
                            margin: EdgeInsets.symmetric(
                              horizontal: measurements.largePadding,
                              vertical: 5,
                            ),
                            child: ExpansionTile(
                              title: Text(
                                teamDetails == null
                                    ? 'Team $teamNumber'
                                    : '${teamDetails['teamLabel']?.isNotEmpty == true ? teamDetails['teamLabel'] : 'Team $teamNumber'} - ${teamDetails['nickname'] ?? ''}',
                                style: TextStyle(color: colors.accentColors[0]),
                              ),
                              subtitle: Text(
                                '${entry['teamName']} (v$version, revisions: $versionCount)',
                                style: TextStyle(color: colors.baseColors[2]),
                              ),
                              leading:
                                  teamDetails != null &&
                                      (teamDetails['logoUrl'] ?? '').isNotEmpty
                                  ? Image.network(
                                      teamDetails['logoUrl']!,
                                      width: 36,
                                      height: 36,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.shield),
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
                                            color: colors.accentColors[0],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      for (final match in relatedMatches)
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            'Match ${match['matchNumber']} (${match['allianceColor']})',
                                          ),
                                          subtitle: Text(
                                            'Points: ${match['calculatedPoints']} | Accuracy: ${match['accuracy']} | Shots: ${match['shotsAttempted']}',
                                          ),
                                        ),
                                      const Divider(),
                                    ],
                                  ),
                                for (final key in entry.keys)
                                  if (key != 'id' &&
                                      key != 'teamNumber' &&
                                      key != 'teamName' &&
                                      key != 'version' &&
                                      key != 'versionCount' &&
                                      (entry[key] ?? '').isNotEmpty)
                                    ListTile(
                                      title: Text(
                                        '$key: ${entry[key]}',
                                        style: TextStyle(
                                          color: colors.baseColors[1],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          );
                        }

                        return Card(
                          color: colors.mainColors[2],
                          margin: EdgeInsets.symmetric(
                            horizontal: measurements.largePadding,
                            vertical: 5,
                          ),
                          child: ExpansionTile(
                            title: Text(
                              'Match ${entry['matchNumber']} - Team ${entry['teamNumber']}',
                              style: TextStyle(color: colors.accentColors[0]),
                            ),
                            subtitle: Text(
                              '${entry['allianceColor']} alliance (v$version, revisions: $versionCount)',
                              style: TextStyle(color: colors.baseColors[2]),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.history),
                                  onPressed: () =>
                                      _openMatchVersionHistory(entry),
                                ),
                                if (backend.canMakeRevisions)
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _openMatchEditDialog(entry),
                                  ),
                              ],
                            ),
                            children: [
                              for (final key in entry.keys)
                                if (key != 'id' &&
                                    key != 'matchNumber' &&
                                    key != 'teamNumber' &&
                                    key != 'allianceColor' &&
                                    key != 'version' &&
                                    key != 'versionCount' &&
                                    (entry[key] ?? '').isNotEmpty)
                                  ListTile(
                                    title: Text(
                                      '$key: ${entry[key]}',
                                      style: TextStyle(
                                        color: colors.baseColors[1],
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
