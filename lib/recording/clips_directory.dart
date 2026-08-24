import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The on-device directory clips are written to and read from —
/// `<app documents>/clips`, created on first use. Shared by [ClipSegmenter]
/// (writes) and `ClipsRepository` (reads) so the path is defined once.
Future<Directory> resolveClipsDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/clips');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
