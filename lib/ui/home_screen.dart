import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../detection/segment_event.dart';
import '../recording/recording_task_handler.dart';
import '../recording/task_message.dart';
import 'results_screen.dart';

/// Build-step 4 scaffold: recording runs inside [RecordingTaskHandler] in the
/// foreground service's isolate, not here — this screen is a thin remote
/// control that starts/stops the service and mirrors its state via
/// `FlutterForegroundTask.addTaskDataCallback`. Extended in later build
/// steps (a dedicated permission-gating flow).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _listening = false;
  bool _recordingClip = false;
  int _clipCount = 0;
  String? _lastClipPath;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    // The service may still be running from a previous app session (it
    // deliberately survives the app being backgrounded/closed).
    FlutterForegroundTask.isRunningService.then((running) {
      if (mounted && running) setState(() => _listening = true);
    });
  }

  void _onTaskData(Object data) {
    final message = decodeTaskMessage(data);
    switch (message) {
      case SegmentEventMessage(:final type):
        setState(() => _recordingClip = type == SegmentEventType.started);
      case ClipSavedMessage(:final path):
        setState(() {
          _clipCount++;
          _lastClipPath = path;
        });
      case null:
        break;
    }
  }

  Future<bool> _ensurePermissions() async {
    if (!await Permission.microphone.request().then((s) => s.isGranted)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record.')),
      );
      return false;
    }

    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  void _initForegroundTask() {
    // Cheap and idempotent (just sets static config) — safe to call every
    // Start rather than tracking whether it already ran.
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'nighttalker_recording',
        channelName: 'Recording session',
        channelDescription: 'Shows while NightTalker is listening overnight.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(), // ClipSegmenter is stream-driven, not polled
        // Keep recording even if the user swipes the app off recent apps —
        // this app's whole purpose is surviving a night the phone isn't touched.
        stopWithTask: false,
      ),
    );
  }

  Future<void> _start() async {
    if (!await _ensurePermissions()) return;

    _initForegroundTask();
    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.microphone],
      notificationTitle: 'NightTalker',
      notificationText: 'Listening… · 0 clips saved',
      callback: startRecordingCallback,
    );
    if (result is ServiceRequestFailure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start recording: ${result.error}')));
      return;
    }

    if (!mounted) return;
    setState(() {
      _listening = true;
      _recordingClip = false;
      _clipCount = 0;
      _lastClipPath = null;
    });
  }

  Future<void> _stop() async {
    await FlutterForegroundTask.stopService();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _recordingClip = false;
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = !_listening ? 'Idle' : (_recordingClip ? 'Recording…' : 'Listening…');

    return Scaffold(
      appBar: AppBar(
        title: const Text('NightTalker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Clips',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResultsScreen())),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('$_clipCount clip${_clipCount == 1 ? '' : 's'} saved'),
            if (_lastClipPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_lastClipPath!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _listening ? _stop : _start,
              child: Text(_listening ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}
