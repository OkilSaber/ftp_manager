import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'ftp_pool.dart';
import 'media_cache.dart';
import 'theme/app_colors.dart';
import 'types/config.dart';
import 'widgets/gradient_scaffold.dart';

class VideoViewerPage extends StatefulWidget {
  final Config config;
  final String workingDirectory;
  final List<FTPEntry> videos;
  final int initialIndex;

  const VideoViewerPage({
    super.key,
    required this.config,
    required this.workingDirectory,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  late final FtpPool _pool;
  final Map<int, _VideoTask> _tasks = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pool = FtpPool(
      config: widget.config,
      workingDirectory: widget.workingDirectory,
    );
    _ensure(_currentIndex);
  }

  Orientation? _lastOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.of(context).orientation;
    if (o == _lastOrientation) return;
    _lastOrientation = o;
    SystemChrome.setEnabledSystemUIMode(
      o == Orientation.landscape
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final task in _tasks.values) {
      task.dispose();
    }
    _pool.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  _VideoTask _ensure(int index) {
    final existing = _tasks[index];
    if (existing != null) return existing;
    final task = _VideoTask(
      entry: widget.videos[index],
      cacheKey: mediaCacheKey(
        widget.config,
        widget.workingDirectory,
        widget.videos[index],
      ),
      pool: _pool,
      onChange: () {
        if (mounted) setState(() {});
      },
    );
    _tasks[index] = task;
    task.start();
    return task;
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _tasks[_currentIndex - 1]?.pause();
    _tasks[_currentIndex + 1]?.pause();
    _ensure(index);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.videos[_currentIndex];
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: widget.videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) => _VideoPage(
        task: _ensure(index),
        active: index == _currentIndex,
      ),
    );
    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: pageView,
      );
    }
    return GradientScaffold(
      appBar: AppBar(
        title: Text(entry.name, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: pageView),
    );
  }
}

class _VideoTask {
  final FTPEntry entry;
  final String cacheKey;
  final FtpPool pool;
  final VoidCallback onChange;

  VideoPlayerController? controller;
  double progress = 0;
  bool downloadDone = false;
  Object? error;

  _VideoTask({
    required this.entry,
    required this.cacheKey,
    required this.pool,
    required this.onChange,
  });

  void start() {
    _run();
  }

  Future<void> _run() async {
    final cached = videoCache[cacheKey];
    if (cached != null && cached.existsSync()) {
      progress = 1.0;
      downloadDone = true;
      onChange();
      await _initController(cached);
      return;
    } else if (cached != null) {
      videoCache.remove(cacheKey);
    }
    await _runDownload();
  }

  Future<void> _runDownload() async {
    try {
      await pool.withConnection((conn) async {
        final dir = await getTemporaryDirectory();
        final safe = entry.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
        final target = File(
          '${dir.path}/ftp_video_${DateTime.now().millisecondsSinceEpoch}_$safe',
        );
        await conn.downloadFile(
          entry.name,
          target,
          onProgress: (percent, received, total) {
            progress = percent / 100;
            onChange();
          },
        );
        downloadDone = true;
        videoCache[cacheKey] = target;
        onChange();
        await _initController(target);
      });
    } catch (e) {
      error = e;
      onChange();
    }
  }

  Future<void> _initController(File file) async {
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      controller = c;
      onChange();
      await c.play();
    } catch (e) {
      error = e;
      await c.dispose();
      onChange();
    }
  }

  void pause() {
    controller?.pause();
  }

  void dispose() {
    controller?.dispose();
  }
}

class _VideoPage extends StatefulWidget {
  final _VideoTask task;
  final bool active;
  const _VideoPage({required this.task, required this.active});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (!widget.active) widget.task.controller?.pause();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.mintAccent : AppColors.forestGreen;

    if (task.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.errorRed),
              const SizedBox(height: 12),
              Text(task.error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final controller = task.controller;
    Widget videoLayer;
    if (controller != null && controller.value.isInitialized) {
      videoLayer = AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: _PlayerControls(controller: controller, accent: accent),
      );
    } else {
      videoLayer = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                color: accent,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              task.progress > 0
                  ? 'Downloading ${(task.progress * 100).toStringAsFixed(0)}%'
                  : 'Connecting...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Center(child: videoLayer),
        if (controller != null &&
            controller.value.isInitialized &&
            !task.downloadDone)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: LinearProgressIndicator(
              value: task.progress > 0 ? task.progress : null,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.15),
              minHeight: 3,
            ),
          ),
      ],
    );
  }
}

class _PlayerControls extends StatefulWidget {
  final VideoPlayerController controller;
  final Color accent;
  const _PlayerControls({required this.controller, required this.accent});

  @override
  State<_PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<_PlayerControls> {
  bool _scrubbing = false;
  double _scrubValue = 0;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  static const _hideDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted && !_scrubbing) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.controller.value.isPlaying) return;
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _onSurfaceTap() {
    if (!_controlsVisible) {
      _showControls();
      return;
    }
    final c = widget.controller;
    c.value.isPlaying ? c.pause() : c.play();
    _showControls();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
    }
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  Future<void> _seekRelative(Duration delta) async {
    final c = widget.controller;
    final pos = c.value.position + delta;
    final clamped = pos < Duration.zero
        ? Duration.zero
        : (pos > c.value.duration ? c.value.duration : pos);
    await c.seekTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final v = c.value;
    final position = _scrubbing
        ? Duration(milliseconds: _scrubValue.round())
        : v.position;
    final total = v.duration;
    final maxMs = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);

    return Stack(
      children: [
        Positioned.fill(child: VideoPlayer(c)),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onSurfaceTap,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _controlsVisible ? 1 : 0,
              child: Stack(
                children: [
                  // Center transport: -10s, play/pause, +10s.
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(48),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            iconSize: 32,
                            color: Colors.white,
                            icon: const Icon(Icons.replay_10_rounded),
                            onPressed: () {
                              _seekRelative(const Duration(seconds: -10));
                              _showControls();
                            },
                          ),
                          IconButton(
                            iconSize: 56,
                            color: Colors.white,
                            icon: Icon(
                              v.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            onPressed: () {
                              v.isPlaying ? c.pause() : c.play();
                              _showControls();
                            },
                          ),
                          IconButton(
                            iconSize: 32,
                            color: Colors.white,
                            icon: const Icon(Icons.forward_10_rounded),
                            onPressed: () {
                              _seekRelative(const Duration(seconds: 10));
                              _showControls();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom: scrubber + time labels.
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: widget.accent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: widget.accent,
                              overlayColor:
                                  widget.accent.withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              min: 0,
                              max: maxMs,
                              value: position.inMilliseconds
                                  .clamp(0, maxMs.toInt())
                                  .toDouble(),
                              onChangeStart: (_) {
                                _scrubbing = true;
                                _hideTimer?.cancel();
                              },
                              onChanged: (val) {
                                setState(() => _scrubValue = val);
                              },
                              onChangeEnd: (val) async {
                                await c.seekTo(
                                    Duration(milliseconds: val.round()));
                                _scrubbing = false;
                                if (mounted) setState(() {});
                                _showControls();
                              },
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Text(
                                  _fmt(position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _fmt(total),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
