import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/compression_preset.dart';
import '../models/video_file.dart';
import '../services/ffmpeg_service.dart';
import '../services/folder_scanner.dart';
import '../services/settings_service.dart';

class CompressionController extends ChangeNotifier {
  String folderPath = Directory.current.path;
  List<VideoFile> videos = [];
  PresetEncoder encoder = PresetEncoder.nvidia;
  int compressionLevel = 2; // 1–5
  bool deleteAfterCompression = false;
  bool useCustomCommand = false;
  String customArgs = '';
  bool isRunning = false;
  int overallDone = 0;
  int overallTotal = 0;
  final List<String> logs = [];

  final _processRef = ProcessRef();
  bool _cancelled = false;

  int get pendingSelected =>
      videos.where((v) => v.selected && v.status.canBeProcseed).length;

  VideoFile? get currentFile {
    for (final v in videos) {
      if (v.status == VideoStatus.running) return v;
    }
    return null;
  }

  Future<void> initialize() async {
    final s = await SettingsService.load();
    folderPath = s.folderPath;
    encoder = s.encoder;
    compressionLevel = s.compressionLevel;
    deleteAfterCompression = s.deleteAfter;
    useCustomCommand = s.useCustom;
    customArgs = s.customArgs;
    // folderPath is now set; HomeScreen.initState will call loadFolder
  }

  void loadFolder(String path) {
    if (isRunning) return;
    folderPath = path;
    videos = FolderScanner.scan(path);
    logs.clear();
    overallDone = 0;
    overallTotal = 0;
    SettingsService.saveFolderPath(path);
    notifyListeners();
  }

  void reload() => loadFolder(folderPath);

  void toggleSelect(VideoFile video) {
    if (!{VideoStatus.pending, VideoStatus.done}.contains(video.status)) return;
    video.selected = !video.selected;
    notifyListeners();
  }

  void selectAll() {
    for (final v in videos) {
      if (v.status == VideoStatus.pending) v.selected = true;
    }
    notifyListeners();
  }

  void deselectAll() {
    for (final v in videos) {
      if (v.status == VideoStatus.pending) v.selected = false;
    }
    notifyListeners();
  }

  void setEncoder(PresetEncoder value) {
    encoder = value;
    SettingsService.saveEncoder(value);
    notifyListeners();
  }

  void setCompressionLevel(int value) {
    compressionLevel = value.clamp(1, CompressionLevel.count);
    SettingsService.saveCompressionLevel(compressionLevel);
    notifyListeners();
  }

  void setUseCustomCommand(bool value) {
    useCustomCommand = value;
    SettingsService.saveUseCustom(value);
    notifyListeners();
  }

  void setCustomArgs(String value) {
    customArgs = value;
    SettingsService.saveCustomArgs(value);
    // no notifyListeners — called on every keystroke, UI drives via TextField
  }

  void setDeleteAfter(bool value) {
    deleteAfterCompression = value;
    SettingsService.saveDeleteAfter(value);
    notifyListeners();
  }

  Future<void> startCompression() async {
    if (isRunning || pendingSelected == 0) return;
    _cancelled = false;
    isRunning = true;
    logs.clear();
    overallDone = 0;
    notifyListeners();

    final compressedDir =
        Directory(p.join(folderPath, FolderScanner.compressedFolder));
    try {
      if (!compressedDir.existsSync()) compressedDir.createSync();
    } catch (e) {
      _log('✗ Cannot create output folder: $e');
      isRunning = false;
      notifyListeners();
      return;
    }

    final toProcess =
        videos.where((v) => v.selected && v.status.canBeProcseed).toList();
    overallTotal = toProcess.length;
    notifyListeners();

    for (final video in toProcess) {
      if (_cancelled) break;

      video.status = VideoStatus.running;
      video.progress = 0.0;
      _log('⟳  ${video.name}');
      notifyListeners();

      final args = useCustomCommand
          ? customArgs
              .trim()
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .toList()
          : CompressionLevel.args(encoder, compressionLevel);
      final outputPath = FolderScanner.outputPath(folderPath, video.name, args);
      final duration = await FfmpegService.getDuration(video.path);

      int exitCode;
      try {
        exitCode = await FfmpegService.compress(
          inputPath: video.path,
          outputPath: outputPath,
          presetArgs: args,
          totalDuration: duration,
          onProgress: (progress) {
            video.progress = progress;
            notifyListeners();
          },
          processRef: _processRef,
        );
      } catch (e) {
        video.status = VideoStatus.error;
        video.errorMessage = e.toString();
        _log('✗  ${video.name} — $e');
        notifyListeners();
        continue;
      }

      if (_cancelled) {
        video.status = VideoStatus.pending;
        video.progress = 0.0;
        _deleteFile(outputPath);
        _log('—  ${video.name} cancelled');
      } else if (exitCode == 0) {
        video.status = VideoStatus.done;
        video.progress = 1.0;
        overallDone++;
        _log('✓  ${video.name} → ${p.basename(outputPath)}');
        if (deleteAfterCompression) {
          if (_deleteFile(video.path)) {
            _log('   deleted source: ${video.name}');
          } else {
            _log('   warning: could not delete: ${video.name}');
          }
        }
      } else {
        video.status = VideoStatus.error;
        _log('✗  ${video.name} — FFmpeg exit code: $exitCode');
      }
      notifyListeners();
    }

    isRunning = false;
    if (!_cancelled && overallTotal > 0) {
      _log('');
      _log('Done — $overallDone / $overallTotal compressed.');
    }
    notifyListeners();
  }

  void cancel() {
    if (!isRunning) return;
    _cancelled = true;
    _processRef.kill();
  }

  bool _deleteFile(String path) {
    try {
      File(path).deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _log(String message) => logs.add(message);
}
