enum PresetEncoder {
  cpu(label: 'CPU — libx265'),
  nvidia(label: 'NVIDIA — hevc_nvenc');

  const PresetEncoder({required this.label});
  final String label;
}

class CompressionLevel {
  static const int count = 7;

  static const _labels = [
    'Minimal', 'Light', 'Medium', 'Heavy', 'Maximum', 'Extreme', 'Insane',
  ];

  static const _hints = [
    'Best quality · ~20–30% smaller',
    'Good quality · ~35–50% smaller',
    'Balanced · ~50–60% smaller',
    'Aggressive · noticeable quality drop',
    'Maximum · significant quality loss',
    'Extreme · heavy artefacts, ~65–75% smaller',
    'Insane · severe quality loss, ~75–85% smaller',
  ];

  static const _cpuPresets = ['slow', 'medium', 'medium', 'fast', 'fast', 'medium', 'medium'];
  static const _cpuCrfs    = [20,      24,       28,       32,      36,      40,       45];

  static const _nvidiaPresets = ['p7', 'p5', 'p5', 'p3', 'p1', 'p1', 'p1'];
  static const _nvidiaCqs     = [20,   24,   28,   32,   36,   40,   45];

  /// [level] is 1-based (1 = minimal compression, 5 = maximum compression).
  static String label(int level) => _labels[level - 1];
  static String hint(int level) => _hints[level - 1];

  static String paramLabel(PresetEncoder encoder, int level) {
    final i = level - 1;
    if (encoder == PresetEncoder.cpu) {
      return 'preset ${_cpuPresets[i]}  ·  crf ${_cpuCrfs[i]}';
    }
    return 'preset ${_nvidiaPresets[i]}  ·  cq ${_nvidiaCqs[i]}';
  }

  static List<String> args(PresetEncoder encoder, int level) {
    final i = level - 1;
    if (encoder == PresetEncoder.cpu) {
      return [
        '-c:v', 'libx265',
        '-preset', _cpuPresets[i],
        '-crf', '${_cpuCrfs[i]}',
        '-c:a', 'copy',
      ];
    }
    return [
      '-c:v', 'hevc_nvenc',
      '-preset', _nvidiaPresets[i],
      '-cq', '${_nvidiaCqs[i]}',
      '-c:a', 'copy',
    ];
  }
}
