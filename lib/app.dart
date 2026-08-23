import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

/// Root widget. Routing to a results screen is added in a later build step.
class NightTalkerApp extends StatelessWidget {
  const NightTalkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NightTalker',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const HomeScreen(),
    );
  }
}
