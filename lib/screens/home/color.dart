import 'package:flutter/material.dart';

class Colorings {
  List<Color> mainColors = [
    Color.fromARGB(255, 18, 66, 241), //main
    Color(0xFF0B2EB0), //lighter
    Color(0xFF061C6C), //darker
  ];
  List accentColors = [
    Color(0xFFFCA10F), //main
    Color(0xFFB0710B), //lighter
    Color(0xFF6C4506), //darker
  ];
  List baseColors = [
    Color(0xFFFFFFFF), //white
    Color(0xFFF5F5F5), //light grey
    Color(0xFFBEBEBE), //medium grey
    Color(0xFF7E7E7E), //dark grey
    Color(0xFF000000), //black
  ];
}

class Measurements {
  double smallPadding = 4.0;
  double mediumPadding = 8.0;
  double largePadding = 16.0;
  double extraLargePadding = 32.0;
  double clickHeight = 48.0;
}
