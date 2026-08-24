import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme.dart';
import '../detection/segment_event.dart';
import '../recording/recording_task_handler.dart';
import '../recording/task_message.dart';
import 'breathing_ring.dart';
import 'permissions_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

/// Recording runs inside [RecordingTaskHandler] in the foreground service's
/// isolate, not here — this screen is a thin remote control that starts/
/// stops the service and mirrors its state via
/// `FlutterForegroundTask.addTaskDataCallback`. Reached only once the
/// microphone permission is granted — see [PermissionsScreen], which owns
/// all permission requesting; this screen only ever checks (never requests)
/// and redirects back there if something's missing.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _listening = false;
  bool _recordingClip = false;
  int _clipCount = 0;

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
      case ClipSavedMessage():
        setState(() => _clipCount++);
      case AutoStoppedMessage():
        setState(() {
          _listening = false;
          _recordingClip = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Session auto-stopped after 11h to save battery/storage.')));
        }
      case null:
        break;
    }
  }

  /// Read-only — requesting permissions is [PermissionsScreen]'s job.
  /// Redirects there (replacing this route) if the microphone got revoked
  /// mid-session (e.g. via system settings) instead of trying to record
  /// without it.
  Future<bool> _ensureMicPermission() async {
    if (await Permission.microphone.status.then((s) => s.isGranted)) return true;

    if (!mounted) return false;
    unawaited(
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PermissionsScreen())),
    );
    return false;
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
    if (!await _ensureMicPermission()) return;

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
    final ringState = !_listening
        ? RingState.idle
        : (_recordingClip ? RingState.recording : RingState.listening);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NightTalker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Clips',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResultsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              BreathingRing(
                state: ringState,
                size: 260,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(status, maxLines: 1, style: textTheme.titleLarge),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _clipCount == 0 ? 'No clips yet' : '$_clipCount clip${_clipCount == 1 ? '' : 's'} saved',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _listening ? _stop : _start,
                  child: Text(_listening ? 'Stop listening' : 'Start listening'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
