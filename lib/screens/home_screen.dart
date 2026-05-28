import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../controllers/compression_controller.dart';
import '../models/compression_preset.dart';
import '../models/video_file.dart';

const _kBg = Color(0xFF1A1A1A);
const _kSurface = Color(0xFF2A2A2A);
const _kBorder = Color(0xFF3A3A3A);
const _kAccent = Color(0xFF0078D4);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFEF5350);
const _kMuted = Color(0xFF888888);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final CompressionController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _logScrollController = ScrollController();
  late final TextEditingController _customArgsController;

  CompressionController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _customArgsController = TextEditingController(text: _ctrl.customArgs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.loadFolder(_ctrl.folderPath);
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    _customArgsController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select video folder',
    );
    if (path != null) _ctrl.loadFolder(path);
  }

  void _scrollLogToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients &&
          _logScrollController.position.hasContentDimensions) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        if (_ctrl.isRunning) _scrollLogToBottom();
        return _buildScaffold();
      },
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF252525),
        elevation: 0,
        title: const Text(
          'Video Compressor',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_ctrl.isRunning)
            IconButton(
              icon: const Icon(Icons.refresh, color: _kMuted, size: 20),
              tooltip: 'Refresh folder',
              onPressed: _ctrl.reload,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FolderRow(
              path: _ctrl.folderPath,
              onBrowse: _ctrl.isRunning ? null : _pickFolder,
            ),
            const SizedBox(height: 10),
            _ListHeader(
              videoCount: _ctrl.videos.length,
              selectedCount: _ctrl.pendingSelected,
              isRunning: _ctrl.isRunning,
              onSelectAll: _ctrl.selectAll,
              onDeselectAll: _ctrl.deselectAll,
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 3,
              child: _VideoList(
                videos: _ctrl.videos,
                onToggle: _ctrl.toggleSelect,
                isRunning: _ctrl.isRunning,
              ),
            ),
            const SizedBox(height: 12),
            _OptionsPanel(
              controller: _ctrl,
              customArgsController: _customArgsController,
            ),
            const SizedBox(height: 12),
            _ActionButton(controller: _ctrl),
            if (_ctrl.isRunning) ...[
              const SizedBox(height: 12),
              _ProgressPanel(controller: _ctrl),
            ],
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: _LogPanel(
                logs: _ctrl.logs,
                scrollController: _logScrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Folder row
// ---------------------------------------------------------------------------

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.path, required this.onBrowse});
  final String path;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              path,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.folder_open, size: 16),
          label: const Text('Browse'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kSurface,
            foregroundColor: Colors.white70,
            side: const BorderSide(color: _kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// List header
// ---------------------------------------------------------------------------

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.videoCount,
    required this.selectedCount,
    required this.isRunning,
    required this.onSelectAll,
    required this.onDeselectAll,
  });
  final int videoCount;
  final int selectedCount;
  final bool isRunning;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$videoCount video${videoCount == 1 ? '' : 's'}  •  $selectedCount selected',
          style: const TextStyle(color: _kMuted, fontSize: 12),
        ),
        const Spacer(),
        if (!isRunning) ...[
          _TextBtn('Select all', onSelectAll),
          const SizedBox(width: 8),
          _TextBtn('Deselect all', onDeselectAll),
        ],
      ],
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child:
            Text(label, style: const TextStyle(color: _kAccent, fontSize: 12)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video list
// ---------------------------------------------------------------------------

class _VideoList extends StatelessWidget {
  const _VideoList({
    required this.videos,
    required this.onToggle,
    required this.isRunning,
  });
  final List<VideoFile> videos;
  final void Function(VideoFile) onToggle;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _kSurface,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text(
            'No video files found in this folder.',
            style: TextStyle(color: _kMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ListView.separated(
          itemCount: videos.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: _kBorder),
          itemBuilder: (_, i) => _VideoItem(
            video: videos[i],
            onToggle: onToggle,
            isRunning: isRunning,
          ),
        ),
      ),
    );
  }
}

class _VideoItem extends StatelessWidget {
  const _VideoItem({
    required this.video,
    required this.onToggle,
    required this.isRunning,
  });
  final VideoFile video;
  final void Function(VideoFile) onToggle;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final isPending =
        {VideoStatus.pending, VideoStatus.done}.contains(video.status);
    final isSkipped = video.status == VideoStatus.skipped;
    final isCurrentlyRunning = video.status == VideoStatus.running;

    return InkWell(
      onTap: (!isRunning && isPending) ? () => onToggle(video) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IgnorePointer(
                    child: _StatusIcon(video: video, isRunning: isRunning)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    video.name,
                    style: TextStyle(
                      color: isSkipped ? _kMuted : Colors.white,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  video.sizeLabel,
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                ),
                if (isSkipped) ...[
                  const SizedBox(width: 10),
                  const Text(
                    'already compressed',
                    style: TextStyle(color: _kMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
            if (isCurrentlyRunning) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: video.progress,
                backgroundColor: _kBorder,
                valueColor: const AlwaysStoppedAnimation(_kAccent),
                minHeight: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.video, required this.isRunning});
  final VideoFile video;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    switch (video.status) {
      case VideoStatus.pending:
        return SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: video.selected,
            onChanged: isRunning ? null : (_) {},
            side: const BorderSide(color: _kMuted),
            activeColor: _kAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      case VideoStatus.skipped:
        return const Icon(Icons.remove, size: 18, color: _kMuted);
      case VideoStatus.running:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent),
        );
      case VideoStatus.done:
        return SizedBox(
          height: 20,
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Checkbox(
                  value: video.selected,
                  onChanged: isRunning ? null : (_) {},
                  side: const BorderSide(color: _kMuted),
                  activeColor: _kAccent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 18, color: _kGreen),
            ],
          ),
        );
      case VideoStatus.error:
        return const Icon(Icons.error, size: 18, color: _kRed);
    }
  }
}

// ---------------------------------------------------------------------------
// Options panel
// ---------------------------------------------------------------------------

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({
    required this.controller,
    required this.customArgsController,
  });
  final CompressionController controller;
  final TextEditingController customArgsController;

  @override
  Widget build(BuildContext context) {
    final disabled = controller.useCustomCommand;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: disabled ? 0.35 : 1.0,
            child: IgnorePointer(
              ignoring: disabled,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _EncoderSelector(controller: controller)),
                  const SizedBox(width: 24),
                  _DeleteCheckbox(controller: controller),
                ],
              ),
            ),
          ),
          Opacity(
            opacity: disabled ? 0.35 : 1.0,
            child: IgnorePointer(
              ignoring: disabled,
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  _CompressionSlider(controller: controller),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 12),
          _CustomCommandSection(
            controller: controller,
            textController: customArgsController,
          ),
        ],
      ),
    );
  }
}

class _EncoderSelector extends StatelessWidget {
  const _EncoderSelector({required this.controller});
  final CompressionController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Encoder', style: TextStyle(color: _kMuted, fontSize: 11)),
        const SizedBox(height: 4),
        for (final enc in PresetEncoder.values)
          _RadioRow(
            label: enc.label,
            selected: controller.encoder == enc,
            enabled: !controller.isRunning,
            onTap: () => controller.setEncoder(enc),
          ),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? _kAccent : _kMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : _kMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompressionSlider extends StatelessWidget {
  const _CompressionSlider({required this.controller});
  final CompressionController controller;

  static const _levelColors = [
    Color(0xFF4CAF50), // 1 — green
    Color(0xFF8BC34A), // 2
    Color(0xFFFFC107), // 3 — amber
    Color(0xFFFF7043), // 4 — orange
    Color(0xFFEF5350), // 5 — red
    Color(0xFFB71C1C), // 6 — dark red (extreme)
    Color(0xFF7B1FA2), // 7 — purple (insane)
  ];

  @override
  Widget build(BuildContext context) {
    final level = controller.compressionLevel;
    final enabled = !controller.isRunning;
    final color = _levelColors[level - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Compression',
                style: TextStyle(color: _kMuted, fontSize: 11)),
            Row(
              children: [
                Text(
                  CompressionLevel.label(level),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${CompressionLevel.paramLabel(controller.encoder, level)})',
                  style: const TextStyle(color: _kMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: _kBorder,
            thumbColor: color,
            overlayColor: color.withAlpha(40),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
            activeTickMarkColor: color.withAlpha(120),
            inactiveTickMarkColor: _kBorder,
            trackHeight: 3,
          ),
          child: Slider(
            value: level.toDouble(),
            min: 1,
            max: CompressionLevel.count.toDouble(),
            divisions: CompressionLevel.count - 1,
            onChanged: enabled
                ? (v) => controller.setCompressionLevel(v.round())
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Best quality',
                  style: TextStyle(color: _kMuted, fontSize: 10)),
              Text(
                CompressionLevel.hint(level),
                style: const TextStyle(color: _kMuted, fontSize: 10),
              ),
              const Text('Smallest file',
                  style: TextStyle(color: _kMuted, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomCommandSection extends StatelessWidget {
  const _CustomCommandSection({
    required this.controller,
    required this.textController,
  });
  final CompressionController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    final enabled = !controller.isRunning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: enabled
              ? () =>
                  controller.setUseCustomCommand(!controller.useCustomCommand)
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: controller.useCustomCommand,
                  onChanged: enabled
                      ? (v) => controller.setUseCustomCommand(v ?? false)
                      : null,
                  side: const BorderSide(color: _kMuted),
                  activeColor: _kAccent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Use custom FFmpeg args',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        if (controller.useCustomCommand) ...[
          const SizedBox(height: 10),
          TextField(
            controller: textController,
            enabled: enabled,
            onChanged: controller.setCustomArgs,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '-c:v libx265 -preset medium -crf 28 -c:a copy',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
              helperText: 'ffmpeg -i input.mp4  [ your args ]  output.mp4',
              helperStyle: const TextStyle(color: _kMuted, fontSize: 10),
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kAccent),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ],
    );
  }
}

class _DeleteCheckbox extends StatelessWidget {
  const _DeleteCheckbox({required this.controller});
  final CompressionController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('After compression',
            style: TextStyle(color: _kMuted, fontSize: 11)),
        const SizedBox(height: 4),
        InkWell(
          onTap: controller.isRunning
              ? null
              : () =>
                  controller.setDeleteAfter(!controller.deleteAfterCompression),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: controller.deleteAfterCompression,
                  onChanged: controller.isRunning
                      ? null
                      : (v) => controller.setDeleteAfter(v ?? false),
                  activeColor: _kRed,
                  side: const BorderSide(color: _kMuted),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Text(
                  'Delete source video',
                  style: TextStyle(
                    color: controller.isRunning ? _kMuted : Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.controller});
  final CompressionController controller;

  @override
  Widget build(BuildContext context) {
    final canStart = !controller.isRunning && controller.pendingSelected > 0;

    if (controller.isRunning) {
      return OutlinedButton.icon(
        onPressed: controller.cancel,
        icon: const Icon(Icons.stop, size: 16, color: _kRed),
        label: const Text('Cancel', style: TextStyle(color: _kRed)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _kRed),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: canStart ? controller.startCompression : null,
      icon: const Icon(Icons.compress, size: 16),
      label: Text(
        canStart
            ? 'Compress ${controller.pendingSelected} video${controller.pendingSelected == 1 ? '' : 's'}'
            : 'Select videos to compress',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _kSurface,
        disabledForegroundColor: _kMuted,
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress panel
// ---------------------------------------------------------------------------

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.controller});
  final CompressionController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.currentFile;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current != null) ...[
            Row(
              children: [
                const Text('Current:',
                    style: TextStyle(color: _kMuted, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(current.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: _kAccent, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: current.progress,
              backgroundColor: _kBorder,
              valueColor: const AlwaysStoppedAnimation(_kAccent),
              minHeight: 4,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Text('Overall:',
                  style: TextStyle(color: _kMuted, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: controller.overallTotal > 0
                      ? controller.overallDone / controller.overallTotal
                      : 0,
                  backgroundColor: _kBorder,
                  valueColor: const AlwaysStoppedAnimation(_kGreen),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${controller.overallDone} / ${controller.overallTotal}',
                style: const TextStyle(color: _kMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log panel
// ---------------------------------------------------------------------------

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.logs, required this.scrollController});
  final List<String> logs;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: logs.isEmpty
          ? const Center(
              child: Text(
                'Output will appear here…',
                style: TextStyle(color: _kMuted, fontSize: 12),
              ),
            )
          : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: logs.length,
              itemBuilder: (_, i) => Text(
                logs[i],
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  color: _logColor(logs[i]),
                  height: 1.6,
                ),
              ),
            ),
    );
  }

  Color _logColor(String line) {
    if (line.startsWith('✓')) return _kGreen;
    if (line.startsWith('✗')) return _kRed;
    if (line.startsWith('Done')) return _kGreen;
    if (line.startsWith('—')) return _kMuted;
    return Colors.white70;
  }
}
