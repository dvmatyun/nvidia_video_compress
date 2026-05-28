import 'dart:convert';
import 'dart:io';

class ProcessRef {
  Process? process;
  void kill() => process?.kill();
}

class FfmpegService {
  static Future<double?> getDuration(String inputPath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        inputPath,
      ]);
      return double.tryParse((result.stdout as String).trim());
    } catch (_) {
      return null;
    }
  }

  static Future<int> compress({
    required String inputPath,
    required String outputPath,
    required List<String> presetArgs,
    double? totalDuration,
    void Function(double progress)? onProgress,
    ProcessRef? processRef,
  }) async {
    final process = await Process.start('ffmpeg', [
      '-i', inputPath,
      ...presetArgs,
      '-y',
      outputPath,
    ]);

    if (processRef != null) processRef.process = process;

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (totalDuration == null || totalDuration <= 0 || onProgress == null) return;
      final match = RegExp(r'time=(\d+):(\d+):(\d+\.?\d*)').firstMatch(line);
      if (match == null) return;
      final h = double.parse(match.group(1)!);
      final m = double.parse(match.group(2)!);
      final s = double.parse(match.group(3)!);
      final elapsed = h * 3600 + m * 60 + s;
      onProgress((elapsed / totalDuration).clamp(0.0, 1.0));
    });

    return process.exitCode;
  }
}
