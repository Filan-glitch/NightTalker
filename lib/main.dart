import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // TODO(step 5): FlutterForegroundTask.initCommunicationPort() must be
  // called here, before runApp(), once the foreground task handler exists.
  runApp(const ProviderScope(child: NightTalkerApp()));
}
