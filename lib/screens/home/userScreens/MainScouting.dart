import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spectator/bridge.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/theme/appearance.dart';

import 'ScoutingPage.dart';

class MainScouting extends StatefulWidget {
  const MainScouting({super.key});

  @override
  State<MainScouting> createState() => _MainScoutingState();
}

class _MainScoutingState extends State<MainScouting> {
  final dynamic colorings = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  bool _loading = true;
  String _error = '';
  final Map<int, String> _teamLogos = {};
  final Set<int> _loadingLogos = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
    });

    await backend.ready;

    try {
      await backend.fetchMainEventsFromTba();
      _error = '';
    } catch (error) {
      // Only show error if there's no cached data to display.
      if (backend.teamsList.isEmpty) {
        _error = _errorText(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
    _prefetchTeamLogos();
  }

  Future<void> _prefetchTeamLogos() async {
    final teams = <int>[];
    final seen = <int>{};
    for (final match in backend.teamsList) {
      for (final t in match) {
        final n = t as int;
        if (n != 0 &&
            !seen.contains(n) &&
            !_teamLogos.containsKey(n) &&
            !_loadingLogos.contains(n)) {
          teams.add(n);
          seen.add(n);
        }
      }
    }

    for (final teamNumber in teams) {
      if (!mounted) return;
      _loadingLogos.add(teamNumber);
      try {
        final info = await backend.fetchTeamInfoFromBlueAlliance(
          teamNumber.toString(),
        );
        final url = info['logoUrl'] ?? '';
        if (mounted) {
          setState(() {
            _teamLogos[teamNumber] = url;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _teamLogos[teamNumber] = '';
          });
        }
      } finally {
        _loadingLogos.remove(teamNumber);
      }
    }
  }

  Future<void> _openEventSearch() async {
    final selectedEvent = await showSearch<String>(
      context: context,
      delegate: CustomSearchDelegate(events: backend.eventsList),
    );

    if (selectedEvent == null || selectedEvent.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      await backend.updateMatches(selectedEvent);
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
    _prefetchTeamLogos();
  }

  Future<void> _openEventKeyPrompt() async {
    String eventKey = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Load Event by Key'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Example: 2026pach',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => eventKey = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Load'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _loading = true;
    });

    try {
      await backend.fetchMatchesByEventKey(eventKey.trim());
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
    _prefetchTeamLogos();
  }

  Widget _buildTeamButton({
    required int matchNumber,
    required int teamNumber,
    required bool isRed,
    required double fontSize,
  }) {
    final isPlaceholder = teamNumber == 0;
    final logoUrl = isPlaceholder ? null : _teamLogos[teamNumber];
    final allianceColor = isRed ? Colors.redAccent : Colors.blueAccent;

    return Card(
      margin: EdgeInsets.zero,
      color: allianceColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isPlaceholder
            ? null
            : () async {
                if (!backend.isAuthenticated) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Login to submit match scouting data.'),
                    ),
                  );
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScoutingPage(
                      matchNumber: matchNumber.toString(),
                      teamNumber: teamNumber.toString(),
                      allianceColor: isRed ? 'Red' : 'Blue',
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: isPlaceholder
                    ? Icon(
                        Icons.help_outline,
                        size: 24,
                        color: Colors.white.withValues(alpha: 0.6),
                      )
                    : logoUrl != null && logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        fadeInDuration: const Duration(milliseconds: 300),
                        placeholder: (_, __) => SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.shield,
                          size: 24,
                          color: Colors.white,
                        ),
                      )
                    : _loadingLogos.contains(teamNumber)
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : Icon(Icons.shield, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                isPlaceholder ? 'TBD' : '$teamNumber',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize - 2,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final usedSettings = Provider.of<SettingsModel>(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final buttonBackground = scheme.surface;
    final buttonForeground = scheme.onSurface.withValues(alpha: 0.75);
    final selectedEventName = backend.selectedEventName;
    final selectedEventKey = backend.selectedEventKey;
    final matchesStatus = backend.matchesStatusMessage;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: measurements.extraLargePadding),
          SizedBox(
            width: width - measurements.extraLargePadding,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: measurements.clickHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Material(
                        color: buttonBackground,
                        child: IconButton(
                          onPressed: _openEventSearch,
                          icon: Icon(Icons.search, color: buttonForeground),
                          tooltip: 'Search Team Events',
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: measurements.mediumPadding),
                SizedBox(
                  height: measurements.clickHeight,
                  width: measurements.clickHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Material(
                      color: buttonBackground,
                      child: IconButton(
                        onPressed: _openEventKeyPrompt,
                        icon: Icon(Icons.key, color: buttonForeground),
                        tooltip: 'Enter Event Key',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: measurements.largePadding),
          if (selectedEventName.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: measurements.largePadding,
              ),
              child: Text(
                'Event: $selectedEventName ($selectedEventKey)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: usedSettings.fontSize,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          if (selectedEventName.isNotEmpty)
            SizedBox(height: measurements.largePadding),
          if (_loading)
            Padding(
              padding: EdgeInsets.only(top: measurements.largePadding),
              child: CircularProgressIndicator(
                color: colorings.accentColors[0],
              ),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(measurements.largePadding),
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (!_loading && _error.isEmpty && matchesStatus.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: measurements.largePadding,
              ),
              child: Text(
                matchesStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: usedSettings.fontSize,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          if (!_loading)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: width < 600
                  ? SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: measurements.mediumPadding,
                      mainAxisSpacing: measurements.mediumPadding,
                      childAspectRatio: 3 / 4,
                    )
                  : SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      crossAxisSpacing: measurements.mediumPadding,
                      mainAxisSpacing: measurements.mediumPadding,
                      childAspectRatio: 3 / 4,
                    ),
              itemBuilder: (BuildContext context, int matchesIndex) {
                final match = backend.teamsList[matchesIndex];
                return Card(
                  color: colorings.accentColors[0],
                  child: Padding(
                    padding: EdgeInsets.all(measurements.smallPadding),
                    child: Column(
                      children: [
                        Text(
                          'Match ${matchesIndex + 1}',
                          style: TextStyle(
                            color: colorings.baseColors[0],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: measurements.smallPadding),
                        for (int r = 0; r < 3; r++) ...[
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTeamButton(
                                    matchNumber: matchesIndex + 1,
                                    teamNumber: match[r] as int,
                                    isRed: true,
                                    fontSize: usedSettings.fontSize,
                                  ),
                                ),
                                SizedBox(width: measurements.smallPadding),
                                Expanded(
                                  child: _buildTeamButton(
                                    matchNumber: matchesIndex + 1,
                                    teamNumber: match[r + 3] as int,
                                    isRed: false,
                                    fontSize: usedSettings.fontSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r < 2) SizedBox(height: measurements.smallPadding),
                        ],
                      ],
                    ),
                  ),
                );
              },
              itemCount: backend.teamsList.length,
            ),
        ],
      ),
    );
  }
}

class CustomSearchDelegate extends SearchDelegate<String> {
  CustomSearchDelegate({required this.events});

  final List<String> events;

  List<String> _queryEvents(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      return events;
    }

    return events
        .where((event) => event.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _resultsList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _resultsList(context);
  }

  Widget _resultsList(BuildContext context) {
    final usedSettings = Provider.of<SettingsModel>(context);
    final matches = _queryEvents(query);

    if (matches.isEmpty) {
      return const Center(child: Text('No events found'));
    }

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final result = matches[index];
        return ListTile(
          title: Text(
            result,
            style: TextStyle(fontSize: usedSettings.fontSize),
          ),
          hoverColor: Colorings().accentColors[0],
          onTap: () {
            close(context, result);
          },
        );
      },
    );
  }
}
