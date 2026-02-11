import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spectator/firebase_options.dart';
import 'package:spectator/screens/home/home.dart';
import 'package:spectator/screens/wrapper.dart';
import 'package:device_preview/device_preview.dart';
import 'package:spectator/screens/home/userScreens/PitScoutingFolder/ScoutingModel.dart';
// ... existing imports
import 'package:spectator/screens/home/userScreens/PitScoutingFolder/ScoutingModel.dart'; // Add this import

Future<void> main() async {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SettingsModel()),
        ChangeNotifierProvider(
          create: (context) => ScoutingProvider(),
        ), // Add this line
      ],
      child: Spectator(),
    ),
  );
}
// ... rest of main.dart

class Spectator extends StatelessWidget {
  const Spectator({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spectator',
      home: Wrapper(),
    );
  }
}
