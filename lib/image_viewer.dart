import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:path_provider/path_provider.dart';

import 'ftp_pool.dart';
import 'media_cache.dart';
import 'theme/app_colors.dart';
import 'types/config.dart';
import 'widgets/glass_card.dart';
import 'widgets/gradient_scaffold.dart';

class ImageViewerPage extends StatefulWidget {
  final Config config;
  final String workingDirectory;
  final List<FTPEntry> images;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.config,
    required this.workingDirectory,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, File> _files = {};
  final Map<int, double> _progress = {};
  final Map<int, Object> _errors = {};
  final Set<int> _inflight = {};
  late final FtpPool _pool;

  // Window of indexes we still want to fetch / keep cached.
  static const int _prefetchRadius = 1;
  static const int _keepRadius = 2;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pool = FtpPool(
      config: widget.config,
      workingDirectory: widget.workingDirectory,
    );
    _scheduleNeighbours();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pool.dispose();
    super.dispose();
  }

  bool _isWanted(int index) =>
      (index - _currentIndex).abs() <= _prefetchRadius;

  void _scheduleNeighbours() {
    for (int d = 0; d <= _prefetchRadius; d++) {
      _ensureDownload(_currentIndex + d);
      if (d != 0) _ensureDownload(_currentIndex - d);
    }
  }

  String _keyFor(int index) =>
      mediaCacheKey(widget.config, widget.workingDirectory, widget.images[index]);

  void _ensureDownload(int index) {
    if (index < 0 || index >= widget.images.length) return;
    if (_files.containsKey(index) || _inflight.contains(index)) return;

    final key = _keyFor(index);
    final cached = imageFileCache[key];
    if (cached != null && cached.existsSync()) {
      _files[index] = cached;
      _progress[index] = 1.0;
      return;
    } else if (cached != null) {
      imageFileCache.remove(key);
    }

    _inflight.add(index);
    _runDownload(index);
  }

  Future<void> _runDownload(int index) async {
    if (!mounted || !_isWanted(index) || _files.containsKey(index)) {
      _inflight.remove(index);
      return;
    }
    try {
      await _pool.withConnection((conn) async {
        // Re-check after acquiring — user may have swiped past while we waited.
        if (!mounted || !_isWanted(index) || _files.containsKey(index)) return;
        final dir = await getTemporaryDirectory();
        final name = widget.images[index].name;
        final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
        final target = File(
          '${dir.path}/ftp_view_${DateTime.now().millisecondsSinceEpoch}_${index}_$safe',
        );
        await conn.downloadFile(
          name,
          target,
          onProgress: (percent, _, __) {
            if (mounted && _isWanted(index)) {
              setState(() => _progress[index] = percent / 100);
            }
          },
        );
        if (!mounted) {
          target.delete().catchError((_) => target);
          return;
        }
        imageFileCache[_keyFor(index)] = target;
        setState(() => _files[index] = target);
      });
    } catch (e) {
      if (mounted) setState(() => _errors[index] = e);
    } finally {
      _inflight.remove(index);
    }
  }

  void _evictFarFromCurrent() {
    final stale = _files.keys
        .where((i) => (i - _currentIndex).abs() > _keepRadius)
        .toList();
    for (final i in stale) {
      _files.remove(i);
      _progress.remove(i);
      _errors.remove(i);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _evictFarFromCurrent();
    _scheduleNeighbours();
  }

  void _showInfoSheet() {
    final entry = widget.images[_currentIndex];
    final file = _files[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => _InfoSheet(entry: entry, file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.images[_currentIndex];
    return GradientScaffold(
      appBar: AppBar(
        title: Text(entry.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfoSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _ImagePage(
                file: _files[index],
                progress: _progress[index] ?? 0,
                error: _errors[index],
                onSwipeUp: _showInfoSheet,
              ),
            ),
            Positioned(
              bottom: 16,
              child: _SwipeUpHint(onTap: _showInfoSheet),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePage extends StatefulWidget {
  final File? file;
  final double progress;
  final Object? error;
  final VoidCallback onSwipeUp;

  const _ImagePage({
    required this.file,
    required this.progress,
    required this.error,
    required this.onSwipeUp,
  });

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  final TransformationController _ctrl = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTransform);
  }

  void _onTransform() {
    final scale = _ctrl.value.getMaxScaleOnAxis();
    final z = scale > 1.05;
    if (z != _zoomed && mounted) setState(() => _zoomed = z);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.mintAccent : AppColors.forestGreen;

    if (widget.error != null) {
      return _ErrorView(message: widget.error.toString());
    }
    final file = widget.file;
    if (file == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: widget.progress > 0 ? widget.progress : null,
                color: accent,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.progress > 0
                  ? '${(widget.progress * 100).toStringAsFixed(0)}%'
                  : 'Connecting...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: _zoomed
          ? null
          : (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -300) widget.onSwipeUp();
            },
      child: InteractiveViewer(
        transformationController: _ctrl,
        panEnabled: _zoomed,
        minScale: 1.0,
        maxScale: 5,
        child: Center(
          child: Image.file(
            file,
            errorBuilder: (_, __, ___) =>
                const _ErrorView(message: 'Cannot display this image'),
          ),
        ),
      ),
    );
  }
}

class _SwipeUpHint extends StatefulWidget {
  final VoidCallback onTap;
  const _SwipeUpHint({required this.onTap});

  @override
  State<_SwipeUpHint> createState() => _SwipeUpHintState();
}

class _SwipeUpHintState extends State<_SwipeUpHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -4 * _bounce.value),
            child: child,
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.keyboard_arrow_up_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text(
                  'Info',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 56, color: AppColors.errorRed),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSheet extends StatefulWidget {
  final FTPEntry entry;
  final File? file;
  const _InfoSheet({required this.entry, this.file});

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  ui.Image? _decoded;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final f = widget.file;
    if (f == null) return;
    try {
      final bytes = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _decoded = frame.image);
    } catch (_) {}
  }

  String _fmtBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    final size = bytes / math.pow(1024, i);
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final dims = _decoded;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: GlassCard(
          blur: 16,
          borderRadius: 18,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(entry.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              _row(Icons.data_usage_rounded, 'Size', _fmtBytes(entry.size)),
              if (dims != null)
                _row(Icons.aspect_ratio_rounded, 'Dimensions',
                    '${dims.width} × ${dims.height}'),
              _row(Icons.schedule_rounded, 'Modified',
                  entry.modifyTime?.toString() ?? '-'),
              _row(Icons.person_outline_rounded, 'Owner', entry.owner ?? '-'),
              _row(Icons.group_outlined, 'Group', entry.group ?? '-'),
              _row(Icons.lock_outline_rounded, 'Permissions',
                  entry.permission ?? '-'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 10),
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
