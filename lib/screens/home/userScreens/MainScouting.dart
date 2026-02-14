import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spectator/something.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
    });

    try {
      await backend.fetchMainEventsFromTba();
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
  }

  Future<void> _openEventKeyPrompt() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Load Event by Key'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Example: 2026pach',
              border: OutlineInputBorder(),
            ),
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

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await backend.fetchMatchesByEventKey(controller.text.trim());
      _error = '';
    } catch (error) {
      _error = _errorText(error);
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
                        color: colorings.baseColors[0],
                        child: IconButton(
                          onPressed: _openEventSearch,
                          icon: const Icon(Icons.search),
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
                      color: colorings.baseColors[0],
                      child: IconButton(
                        onPressed: _openEventKeyPrompt,
                        icon: const Icon(Icons.key),
                        tooltip: 'Enter Event Key',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          if (!_loading)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: measurements.mediumPadding,
                mainAxisSpacing: measurements.mediumPadding,
                childAspectRatio: 2 / 3,
              ),
              itemBuilder: (BuildContext context, int matchesIndex) {
                return Card(
                  color: colorings.accentColors[0],
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: measurements.mediumPadding,
                      mainAxisSpacing: measurements.mediumPadding,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (BuildContext context, int teamInMatchIndex) {
                      final isRed = teamInMatchIndex % 2 == 0;
                      final teamNumber =
                          backend.teamsList[matchesIndex][teamInMatchIndex];
                      final isPlaceholderTeam = teamNumber == 0;

                      return Card(
                        color: isRed ? Colors.redAccent : Colors.blueAccent,
                        child: TextButton(
                          onPressed: isPlaceholderTeam
                              ? null
                              : () async {
                                  if (!backend.isAuthenticated) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Login to submit match scouting data.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ScoutingPage(
                                        matchNumber: (matchesIndex + 1)
                                            .toString(),
                                        teamNumber: teamNumber.toString(),
                                        allianceColor: isRed ? 'Red' : 'Blue',
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            isPlaceholderTeam ? 'TBD' : 'Team $teamNumber',
                            style: TextStyle(
                              color: colorings.baseColors[0],
                              fontSize: usedSettings.fontSize,
                            ),
                          ),
                        ),
                      );
                    },
                    itemCount: 6,
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
