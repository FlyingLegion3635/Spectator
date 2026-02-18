import 'package:flutter/material.dart';
import 'package:spectator/screens/home/color.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final measurements = Measurements();

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Spectator'),
      ),
      body: ListView(
        padding: EdgeInsets.all(measurements.largePadding),
        children: const [
          Text(
            'Spectator',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            'Built for FRC scouting with pit + match workflows, team management, and collaboration-friendly data tools.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          SizedBox(height: 20),
          Text(
            'Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('- Code-Based student account management'),
          Text('- Customizable Team UI'),
          Text('- Data Revisions'),
          Text('- Datasheet Export'),
          Text('- Passkey support for easy login'),
          Text('- Custom themes to fit your needs'),
          SizedBox(height: 20),
          Text(
            'Tip: Use Account > Appearance to customize your experience.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 50),
          Text(
            'Copyright © 2026 The Flying Legion and App Developers',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 5),
          Text(
            'This app is not officially affiliated with FIRST®, this is a community developed application used in FIRST® FRC Competitions.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
