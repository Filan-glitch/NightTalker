import 'dart:async';

import 'package:flutter/material.dart';

import '../detection/segment_event.dart';
import '../recording/clip_segmenter.dart';

/// Build-step 2 scaffold: [ClipSegmenter] driven directly in the UI isolate
/// — no background service yet. This screen is extended in later build
/// steps (permission gating via `permissions_controller.dart`,
/// foreground-service-backed recording, navigation to a results screen).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _segmenter = ClipSegmenter();
  StreamSubscription<SegmentEvent>? _segmentEventSub;
  StreamSubscription<String>? _clipSavedSub;

  bool _listening = false;
  bool _recordingClip = false;
  int _clipCount = 0;
  String? _lastClipPath;

  @override
  void initState() {
    super.initState();
    _segmentEventSub = _segmenter.onSegmentEvent.listen((event) {
      setState(() => _recordingClip = event.type == SegmentEventType.started);
    });
    _clipSavedSub = _segmenter.onClipSaved.listen((path) {
      setState(() {
        _clipCount++;
        _lastClipPath = path;
      });
    });
  }

  Future<void> _start() async {
    if (!await _segmenter.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record.')),
      );
      return;
    }
    await _segmenter.start();
    if (!mounted) return;
    setState(() => _listening = true);
  }

  Future<void> _stop() async {
    await _segmenter.stop();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _recordingClip = false;
    });
  }

  @override
  void dispose() {
    _segmentEventSub?.cancel();
    _clipSavedSub?.cancel();
    _segmenter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = !_listening ? 'Idle' : (_recordingClip ? 'Recording…' : 'Listening…');

    return Scaffold(
      appBar: AppBar(title: const Text('NightTalker')),
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
