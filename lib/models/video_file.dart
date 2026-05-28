enum VideoStatus {
  pending,
  skipped,
  running,
  done,
  error;

  bool get canBeProcseed => {pending, done}.contains(this);
}

class VideoFile {
  VideoFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.status = VideoStatus.pending,
    this.selected = true,
  });

  final String path;
  final String name;
  final int sizeBytes;
  VideoStatus status;
  bool selected;
  double progress = 0.0;
  String? errorMessage;

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
