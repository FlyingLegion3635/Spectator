import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spectator/screens/home/userScreens/PitScoutingFolder/ScoutingModel.dart';
import 'package:spectator/screens/wrapper.dart';
import 'package:spectator/theme/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsModel()),
        ChangeNotifierProvider(create: (_) => ScoutingProvider()),
      ],
      child: const Spectator(),
    ),
  );
}

class Spectator extends StatelessWidget {
  const Spectator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsModel>(
      builder: (context, settings, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Spectator',
          themeMode: settings.themeMode,
          theme: settings.lightTheme,
          darkTheme: settings.darkTheme,
          home: const Wrapper(),
        );
      },
    );
  }
}
