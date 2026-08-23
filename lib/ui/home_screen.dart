import 'package:flutter/material.dart';

import '../recording/recorder_service.dart';

/// Build-step 1 scaffold: plain foreground recording via [RecorderService]
/// directly in the UI isolate — no background service, no detection yet.
/// This screen is extended in later build steps (permission gating via
/// `permissions_controller.dart`, foreground-service-backed recording, live
/// elapsed time/clip count, navigation to the results screen).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recorderService = RecorderService();
  bool _recording = false;
  String? _lastPath;

  Future<void> _start() async {
    if (!await _recorderService.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record.')),
      );
      return;
    }
    final path = await _recorderService.start();
    if (!mounted) return;
    setState(() {
      _recording = true;
      _lastPath = path;
    });
  }

  Future<void> _stop() async {
    final path = await _recorderService.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _lastPath = path ?? _lastPath;
    });
  }

  @override
  void dispose() {
    _recorderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NightTalker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_recording ? 'Recording…' : 'Idle', style: Theme.of(context).textTheme.headlineSmall),
            if (_lastPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_lastPath!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _recording ? _stop : _start,
              child: Text(_recording ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}
