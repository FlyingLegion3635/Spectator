import 'package:flutter/material.dart';

// The data model for a single scouting entry
class ScoutingEntry {
  final String teamNumber;
  final String teamName;
  final String humanPlayerConfidence;
  final String driveTrain;
  final String mainScoringPotential;
  final String pointsInAutonomous;
  final String teleOperatedCapabilities;

  ScoutingEntry({
    required this.teamNumber,
    required this.teamName,
    required this.humanPlayerConfidence,
    required this.driveTrain,
    required this.mainScoringPotential,
    required this.pointsInAutonomous,
    required this.teleOperatedCapabilities,
  });
}

// The provider that holds the list of all entries
class ScoutingProvider extends ChangeNotifier {
  final List<ScoutingEntry> _entries = [];

  List<ScoutingEntry> get entries => _entries;

  void addEntry(ScoutingEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }
}
