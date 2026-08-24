import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
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

  Future<void> _share(ClipInfo clip) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(clip.path)]));
  }

  Future<void> _delete(ClipInfo clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this clip?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_playingPath == clip.path) {
      await _player.stop();
      _playingPath = null;
    }
    await _repository.deleteClip(clip);
    if (!mounted) return;
    setState(() => _clips = _clips?.where((c) => c.path != clip.path).toList());
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
        [] => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Clips will appear here once NightTalker hears something.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ),
        _ => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            final playing = _playingPath == clip.path;
            return Card(
              child: ListTile(
                leading: IconButton(
                  icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                  onPressed: () => _togglePlay(clip),
                ),
                title: Text(DateFormat.yMMMd().add_Hms().format(clip.recordedAt)),
                subtitle: Text(_formatDuration(clip.duration)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.share), tooltip: 'Share', onPressed: () => _share(clip)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(clip),
                    ),
                  ],
                ),
              ),
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
