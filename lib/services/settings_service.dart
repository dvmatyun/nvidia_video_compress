import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/compression_preset.dart';

class SettingsService {
  static const _kFolderPath       = 'folder_path';
  static const _kEncoder          = 'encoder';
  static const _kCompressionLevel = 'compression_level';
  static const _kDeleteAfter      = 'delete_after';
  static const _kUseCustom        = 'use_custom';
  static const _kCustomArgs       = 'custom_args';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<PersistedSettings> load() async {
    final p = await _instance;

    final encoderName = p.getString(_kEncoder);
    final encoder = PresetEncoder.values.firstWhere(
      (e) => e.name == encoderName,
      orElse: () => PresetEncoder.nvidia,
    );

    final savedPath = p.getString(_kFolderPath);
    final folderPath = (savedPath != null && Directory(savedPath).existsSync())
        ? savedPath
        : Directory.current.path;

    return PersistedSettings(
      folderPath: folderPath,
      encoder: encoder,
      compressionLevel: (p.getInt(_kCompressionLevel) ?? 2).clamp(1, CompressionLevel.count),
      deleteAfter: p.getBool(_kDeleteAfter) ?? false,
      useCustom: p.getBool(_kUseCustom) ?? false,
      customArgs: p.getString(_kCustomArgs) ?? '',
    );
  }

  static Future<void> saveFolderPath(String v) async =>
      (await _instance).setString(_kFolderPath, v);

  static Future<void> saveEncoder(PresetEncoder v) async =>
      (await _instance).setString(_kEncoder, v.name);

  static Future<void> saveCompressionLevel(int v) async =>
      (await _instance).setInt(_kCompressionLevel, v);

  static Future<void> saveDeleteAfter(bool v) async =>
      (await _instance).setBool(_kDeleteAfter, v);

  static Future<void> saveUseCustom(bool v) async =>
      (await _instance).setBool(_kUseCustom, v);

  static Future<void> saveCustomArgs(String v) async =>
      (await _instance).setString(_kCustomArgs, v);
}

class PersistedSettings {
  const PersistedSettings({
    required this.folderPath,
    required this.encoder,
    required this.compressionLevel,
    required this.deleteAfter,
    required this.useCustom,
    required this.customArgs,
  });

  final String folderPath;
  final PresetEncoder encoder;
  final int compressionLevel;
  final bool deleteAfter;
  final bool useCustom;
  final String customArgs;
}
