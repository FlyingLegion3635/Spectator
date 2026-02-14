// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spectator/main.dart';
import 'package:spectator/screens/home/userScreens/PitScoutingFolder/ScoutingModel.dart';
import 'package:spectator/theme/appearance.dart';

void main() {
  testWidgets('App shell renders with providers', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsModel()),
          ChangeNotifierProvider(create: (_) => ScoutingProvider()),
        ],
        child: const Spectator(),
      ),
    );

    await tester.pump();
    expect(find.textContaining('Spectator'), findsWidgets);
  });
}
