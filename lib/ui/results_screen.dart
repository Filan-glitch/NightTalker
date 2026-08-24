import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../playback/clip_info.dart';
import '../playback/clips_repository.dart';

/// Lists saved clips (newest first) with tap-to-play/pause. One shared
/// [AudioPlayer] — starting a different clip stops whichever is playing.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, this.repository});

  final ClipsRepository? repository;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final ClipsRepository _repository = widget.repository ?? ClipsRepository();
  final _player = AudioPlayer();

  List<ClipInfo>? _clips;
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _load();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingPath = null);
      }
    });
  }

  Future<void> _load() async {
    final clips = await _repository.listClips();
    if (!mounted) return;
    setState(() => _clips = clips);
  }

  Future<void> _togglePlay(ClipInfo clip) async {
    if (_playingPath == clip.path) {
      await _player.pause();
      if (!mounted) return;
      setState(() => _playingPath = null);
      return;
    }

    await _player.setFilePath(clip.path);
    await _player.play();
    if (!mounted) return;
    setState(() => _playingPath = clip.path);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clips = _clips;

    return Scaffold(
      appBar: AppBar(title: const Text('Clips')),
      body: switch (clips) {
        null => const Center(child: CircularProgressIndicator()),
        [] => const Center(child: Text('No clips yet.')),
        _ => ListView.builder(
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            final playing = _playingPath == clip.path;
            return ListTile(
              leading: IconButton(
                icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                onPressed: () => _togglePlay(clip),
              ),
              title: Text(DateFormat.yMMMd().add_Hms().format(clip.recordedAt)),
              subtitle: Text(_formatDuration(clip.duration)),
            );
          },
        ),
      },
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
