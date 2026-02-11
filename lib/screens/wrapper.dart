import 'package:flutter/material.dart';
import 'package:spectator/screens/home/home.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    //return home or authenticate widget
    return Home();
  }
}
