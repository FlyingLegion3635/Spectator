import 'package:flutter/material.dart';
import 'package:spectator/theme/appearance.dart';

class Colorings {
  List<Color> get mainColors => ThemePaletteBridge.mainColors;
  List<Color> get accentColors => ThemePaletteBridge.accentColors;
  List<Color> get baseColors => ThemePaletteBridge.baseColors;
}

class Measurements {
  double smallPadding = 4.0;
  double mediumPadding = 8.0;
  double largePadding = 16.0;
  double extraLargePadding = 32.0;
  double clickHeight = 48.0;
}
