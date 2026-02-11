import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/something.dart';
// Assuming color.dart is in the same directory

class ScoutingPage extends StatefulWidget {
  // Added final variables to receive data
  final String matchNumber;
  final String teamNumber;
  final String allianceColor;

  const ScoutingPage({
    super.key,
    required this.matchNumber,
    required this.teamNumber,
    required this.allianceColor,
  });

  @override
  State<ScoutingPage> createState() => _ScoutingPageState();
}

class _ScoutingPageState extends State<ScoutingPage> {
  // --- Theme Helpers ---
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions(); // Access Backend
  // --- Controllers ---
  late TextEditingController _teamNumberController;
  final TextEditingController _fireRateController = TextEditingController();
  late TextEditingController _matchNumberController;

  // --- State Variables ---
  int _ballsShot = 0;
  int? _selectedZoneIndex;
  bool _autoClimb = false;
  String? _climbLevel;
  late String _allianceColor;
  double _accuracy = 1.0; // 1.0 = 100%
  int _calculatedPoints = 0;
  // --- Logic Variables ---
  Timer? _shootingTimer;
  Timer? _clearZoneTimer;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with passed data
    _matchNumberController = TextEditingController(text: widget.matchNumber);
    _teamNumberController = TextEditingController(text: widget.teamNumber);
    _allianceColor = widget.allianceColor;
  }

  void _updatePoints() {
    setState(() {
      _calculatedPoints = backend.calculatePoints(_ballsShot, _accuracy);
    });
  }

  @override
  void dispose() {
    _teamNumberController.dispose();
    _fireRateController.dispose();
    _matchNumberController.dispose();
    _shootingTimer?.cancel();
    _clearZoneTimer?.cancel();
    super.dispose();
  }

  // --- Shooting Logic ---
  void _startShooting() {
    if (_selectedZoneIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please select a field zone first!",
            style: TextStyle(color: colors.baseColors[0]),
          ),
          backgroundColor: colors.mainColors[0],
        ),
      );
      return;
    }

    _clearZoneTimer?.cancel();

    double fireRate = double.tryParse(_fireRateController.text) ?? 1.0;
    if (fireRate <= 0) fireRate = 1.0;
    int intervalMs = (1000 / fireRate).round();

    _shootingTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
      timer,
    ) {
      setState(() {
        _ballsShot++;
        _updatePoints(); // Recalculate points on each shot
      });
    });
  }

  void _stopShooting() {
    _shootingTimer?.cancel();
    _clearZoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _selectedZoneIndex = null;
        });
      }
    });
  }

  // --- Submit Logic ---
  Future<void> _submitData() async {
    List<dynamic> scoutingDataList = [
      _matchNumberController.text,
      _teamNumberController.text,
      _allianceColor,
      _fireRateController.text,
      _ballsShot,
      _accuracy,
      _calculatedPoints,
      _autoClimb,
      _climbLevel ?? 'None',
      DateTime.now().toIso8601String(),
    ];
    final success = await backend.submitMatchData(scoutingDataList, context);
    if (!mounted || !success) return;
    Navigator.pop(context);
  }

  // --- UI Helpers ---
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.baseColors[2]),
      filled: true,
      fillColor: colors.mainColors[2].withOpacity(0.5),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.mainColors[1], width: 1.0),
        borderRadius: BorderRadius.circular(15.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.accentColors[0], width: 2.0),
        borderRadius: BorderRadius.circular(15.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.baseColors[4],
      appBar: AppBar(
        backgroundColor: colors.mainColors[0],
        centerTitle: true,
        title: Text(
          "MATCH SCOUTING",
          style: TextStyle(
            fontSize: 24,
            color: colors.accentColors[0],
            fontFamily: "Monospace",
            letterSpacing: 2.0,
          ),
        ),
        iconTheme: IconThemeData(color: colors.accentColors[0]),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(measurements.largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Match & Team Info (Read Only) ---
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _matchNumberController,
                    readOnly: true, // Prevent editing
                    style: TextStyle(color: colors.baseColors[2]),
                    decoration: _inputDecoration("Match #"),
                  ),
                ),
                SizedBox(width: measurements.mediumPadding),
                Expanded(
                  child: TextField(
                    controller: _teamNumberController,
                    readOnly: true, // Prevent editing
                    style: TextStyle(color: colors.baseColors[2]),
                    decoration: _inputDecoration("Team #"),
                  ),
                ),
              ],
            ),
            SizedBox(height: measurements.largePadding),

            // --- Alliance Display (Fixed) ---
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.mainColors[2].withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: colors.mainColors[1]),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Alliance:",
                    style: TextStyle(color: colors.baseColors[2], fontSize: 16),
                  ),
                  Text(
                    "$_allianceColor Alliance",
                    style: TextStyle(
                      color: _allianceColor == 'Red'
                          ? Colors.redAccent
                          : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: measurements.largePadding),

            // --- Fire Rate Input ---
            TextField(
              controller: _fireRateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: colors.baseColors[2]),
              decoration: _inputDecoration("Fire Rate (Balls/Sec)"),
            ),
            SizedBox(height: measurements.extraLargePadding),

            // --- Field Grid ---
            Text(
              "FIRING ZONE",
              style: TextStyle(
                color: colors.accentColors[0],
                fontWeight: FontWeight.bold,
                fontFamily: "Monospace",
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: measurements.mediumPadding),
            AspectRatio(
              aspectRatio: 1.5,
              child: Container(
                padding: EdgeInsets.all(measurements.smallPadding),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.mainColors[1]),
                  borderRadius: BorderRadius.circular(15),
                  color: colors.mainColors[2],
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedZoneIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedZoneIndex = index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accentColors[0]
                              : colors.baseColors[2],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "Z${index + 1}",
                            style: TextStyle(
                              color: isSelected
                                  ? colors.baseColors[0]
                                  : colors.baseColors[4],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: measurements.largePadding),

            // --- Points Counter ---
            Center(
              child: Text(
                "Attempted: $_ballsShot",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colors.baseColors[0],
                  fontFamily: "Monospace",
                ),
              ),
            ),
            SizedBox(height: measurements.mediumPadding),

            // --- Hold to Shoot Button ---
            GestureDetector(
              onLongPressStart: (_) => _startShooting(),
              onLongPressEnd: (_) => _stopShooting(),
              onTap: () {
                if (_selectedZoneIndex != null) setState(() => _ballsShot++);
              },
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: _selectedZoneIndex != null
                      ? colors.mainColors[0]
                      : colors.baseColors[2],
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    if (_selectedZoneIndex != null)
                      BoxShadow(
                        color: colors.mainColors[0].withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "HOLD TO SHOOT",
                    style: TextStyle(
                      color: _selectedZoneIndex != null
                          ? colors.baseColors[0]
                          : colors.baseColors[4],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Divider(color: colors.mainColors[1]),
            // --- NEW: ACCURACY SLIDER ---
            Text(
              "ACCURACY: ${(_accuracy * 100).toInt()}%",
              style: TextStyle(
                color: colors.accentColors[0],
                fontWeight: FontWeight.bold,
                fontFamily: "Monospace",
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            Slider(
              value: _accuracy,
              min: 0.0,
              max: 1.0,
              divisions: 20, // 5% increments
              activeColor: colors.accentColors[0],
              inactiveColor: colors.mainColors[2],
              onChanged: (val) {
                setState(() {
                  _accuracy = val;
                  _updatePoints(); // Recalculate points on slide
                });
              },
            ),

            // --- NEW: CALCULATED POINTS DISPLAY ---
            Container(
              padding: EdgeInsets.all(measurements.mediumPadding),
              decoration: BoxDecoration(
                color: colors.mainColors[0],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    "CALCULATED POINTS",
                    style: TextStyle(
                      color: colors.accentColors[0],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "$_calculatedPoints",
                    style: TextStyle(
                      color: colors.baseColors[0],
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "* Select a zone first. Selection clears after 2s.",
                style: TextStyle(fontSize: 12, color: colors.baseColors[2]),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: measurements.extraLargePadding),

            // --- Climb / Endgame ---
            Divider(color: colors.mainColors[1]),
            CheckboxListTile(
              title: Text(
                "Autonomous Climb?",
                style: TextStyle(color: colors.baseColors[0], fontSize: 16),
              ),
              value: _autoClimb,
              activeColor: colors.accentColors[0],
              checkColor: colors.baseColors[0],
              side: BorderSide(color: colors.baseColors[2]),
              onChanged: (val) => setState(() => _autoClimb = val!),
            ),
            SizedBox(height: measurements.mediumPadding),

            Text(
              "CLIMB LEVEL",
              style: TextStyle(
                color: colors.accentColors[0],
                fontWeight: FontWeight.bold,
                fontFamily: "Monospace",
              ),
            ),
            SizedBox(height: measurements.smallPadding),

            // Segmented Control
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: colors.mainColors[2],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: colors.mainColors[1]),
              ),
              child: Row(
                children: ['L1', 'L2', 'L3'].map((level) {
                  final isSelected = _climbLevel == level;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _climbLevel = level),
                      child: Container(
                        margin: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accentColors[0]
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            level,
                            style: TextStyle(
                              color: isSelected
                                  ? colors.baseColors[0]
                                  : colors.baseColors[2],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: measurements.extraLargePadding),

            // --- Submit Button ---
            SizedBox(
              height: measurements.clickHeight,
              child: ElevatedButton.icon(
                onPressed: _submitData,
                icon: Icon(Icons.save, color: colors.baseColors[0]),
                label: Text(
                  "SUBMIT DATA",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Monospace",
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentColors[0],
                  foregroundColor: colors.baseColors[0],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
            SizedBox(height: measurements.extraLargePadding),
          ],
        ),
      ),
    );
  }
}
