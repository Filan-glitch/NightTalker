import 'dart:io';

import '../recording/clips_directory.dart';
import 'clip_info.dart';

/// Reads the clips [ClipSegmenter] has written, for the results screen.
class ClipsRepository {
  ClipsRepository({Future<Directory> Function()? clipsDirectory})
    : _clipsDirectory = clipsDirectory ?? resolveClipsDirectory;

  final Future<Directory> Function() _clipsDirectory;

  /// All valid clips currently on disk, newest first.
  Future<List<ClipInfo>> listClips() async {
    final dir = await _clipsDirectory();
    if (!await dir.exists()) return [];

    final infos = <ClipInfo>[];
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final info = await ClipInfo.fromFile(entry);
      if (info != null) infos.add(info);
    }

    infos.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return infos;
  }
}
