import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/video_file.dart';

class FolderScanner {
  static const compressedFolder = 'compressed';

  static const _extensions = {
    '.mp4', '.mov', '.avi', '.mkv',
    '.wmv', '.m4v', '.flv', '.webm',
  };

  static List<VideoFile> scan(String folderPath) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return [];

    final compressedNames = _loadCompressedNames(folderPath);
    final files = <VideoFile>[];

    for (final entity in dir.listSync().whereType<File>()) {
      final ext = p.extension(entity.path).toLowerCase();
      if (!_extensions.contains(ext)) continue;

      final name = p.basename(entity.path);
      final nameKey = p.basenameWithoutExtension(entity.path).toLowerCase();
      final isSkipped = _hasAnyCompressedVariant(nameKey, compressedNames);

      files.add(VideoFile(
        path: entity.path,
        name: name,
        sizeBytes: entity.statSync().size,
        status: isSkipped ? VideoStatus.skipped : VideoStatus.pending,
        selected: !isSkipped,
      ));
    }

    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  /// Generates the output path, embedding a human-readable tag and short hash
  /// of the ffmpeg args so different compression settings never collide.
  ///
  /// Example: `video_cpu_medium_crf28_3fa21c.mp4`
  static String outputPath(
    String folderPath,
    String inputName,
    List<String> args,
  ) {
    final nameWithoutExt = p.basenameWithoutExtension(inputName);
    final suffix = _buildSuffix(args);
    return p.join(folderPath, compressedFolder, '${nameWithoutExt}_$suffix.mp4');
  }

  // ---------------------------------------------------------------------------

  static Set<String> _loadCompressedNames(String folderPath) {
    final dir = Directory(p.join(folderPath, compressedFolder));
    if (!dir.existsSync()) return {};
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basenameWithoutExtension(f.path).toLowerCase())
        .toSet();
  }

  /// A video is skipped if any file in compressed/ is exactly `nameKey`
  /// or starts with `nameKey_` (covers any settings variant).
  static bool _hasAnyCompressedVariant(String nameKey, Set<String> compressedNames) {
    final key = nameKey.toLowerCase();
    return compressedNames.any((n) => n == key || n.startsWith('${key}_'));
  }

  static String _buildSuffix(List<String> args) {
    final argStr = args.join(' ');
    final hash = _shortHash(argStr);

    String tag;
    if (argStr.contains('libx265')) {
      final preset = _argValue(args, '-preset') ?? '';
      final crf    = _argValue(args, '-crf') ?? '';
      tag = 'cpu_${preset}_crf$crf';
    } else if (argStr.contains('hevc_nvenc')) {
      final preset = _argValue(args, '-preset') ?? '';
      final cq     = _argValue(args, '-cq') ?? '';
      tag = 'nv_${preset}_cq$cq';
    } else {
      tag = 'custom';
    }

    return '${tag}_$hash';
  }

  static String? _argValue(List<String> args, String flag) {
    final i = args.indexOf(flag);
    return (i != -1 && i + 1 < args.length) ? args[i + 1] : null;
  }

  /// djb2-derived hash → 6 lowercase hex chars.
  static String _shortHash(String s) {
    int h = 5381;
    for (final c in s.codeUnits) {
      h = ((h << 5) + h + c) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0').substring(0, 6);
  }
}
