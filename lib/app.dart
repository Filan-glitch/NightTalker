import 'package:flutter/material.dart';

import 'ui/permissions_screen.dart';

/// Root widget. Starts at [PermissionsScreen], which advances to
/// [HomeScreen] once the microphone permission is granted.
class NightTalkerApp extends StatelessWidget {
  const NightTalkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NightTalker',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const PermissionsScreen(),
    );
  }
}
