import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // Required before runApp() so the UI isolate can receive data sent from
  // the foreground service's isolate via FlutterForegroundTask.sendDataToMain.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ProviderScope(child: NightTalkerApp()));
}
