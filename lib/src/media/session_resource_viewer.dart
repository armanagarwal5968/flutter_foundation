import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'resource_cache_stub.dart'
    if (dart.library.io) 'resource_cache_io.dart'
    as resource_cache;
import 'resource_file_opener_stub.dart'
    if (dart.library.io) 'resource_file_opener_io.dart'
    as resource_file_opener;
import 'resource_platform_stub.dart'
    if (dart.library.io) 'resource_platform_io.dart'
    as resource_platform;
import 'session_media.dart';

/// A grouped, cache-aware viewer for patient session resources.
class SessionResourcesPage extends StatefulWidget {
  const SessionResourcesPage({
    required this.assets,
    required this.repository,
    super.key,
  });

  final List<SessionMediaAsset> assets;
  final SessionMediaRepository repository;

  @override
  State<SessionResourcesPage> createState() => _SessionResourcesPageState();
}

class _SessionResourcesPageState extends State<SessionResourcesPage> {
  String? _activeVideoId;

  @override
  Widget build(BuildContext context) {
    final images = _ofType(SessionMediaType.image);
    final videos = _ofType(SessionMediaType.video);
    final pdfs = _ofType(SessionMediaType.pdf);
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (images.isNotEmpty) ...[
            _GroupHeader(title: 'Images', count: images.length),
            _ImageGrid(assets: images, repository: widget.repository),
          ],
          if (videos.isNotEmpty) ...[
            _GroupHeader(title: 'Videos', count: videos.length),
            for (final asset in videos)
              _VideoCard(
                asset: asset,
                repository: widget.repository,
                active: _activeVideoId == asset.id,
                onActivate: () => setState(() => _activeVideoId = asset.id),
              ),
          ],
          if (pdfs.isNotEmpty) ...[
            _GroupHeader(title: 'PDFs', count: pdfs.length),
            for (final asset in pdfs)
              _PdfCard(asset: asset, repository: widget.repository),
          ],
        ],
      ),
    );
  }

  List<SessionMediaAsset> _ofType(SessionMediaType type) => widget.assets
      .where((asset) => asset.type == type)
      .toList(growable: false);
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text('$count', style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.assets, required this.repository});

  final List<SessionMediaAsset> assets;
  final SessionMediaRepository repository;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 3 : 2;
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        itemCount: assets.length,
        itemBuilder:
            (_, index) =>
                _ImageCard(asset: assets[index], repository: repository),
      );
    },
  );
}

class _ImageCard extends StatefulWidget {
  const _ImageCard({required this.asset, required this.repository});

  final SessionMediaAsset asset;
  final SessionMediaRepository repository;

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  late final Future<_ResourceSource> _source = _resolveSource(
    widget.asset,
    widget.repository,
    waitForCache: true,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<_ResourceSource>(
    future: _source,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _ErrorCard(asset: widget.asset);
      }
      if (!snapshot.hasData) return const _LoadingCard();
      final source = snapshot.data!;
      return Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) =>
                          _FullScreenImage(asset: widget.asset, source: source),
                ),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:
                    kIsWeb
                        ? resource_platform.resourceImage(
                          url: source.url,
                          localPath: source.localPath,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        )
                        : Hero(
                          tag: 'resource-image-${widget.asset.id}',
                          child: resource_platform.resourceImage(
                            url: source.url,
                            localPath: source.localPath,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, _, _) => const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                          ),
                        ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_out_map, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.asset.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.asset, required this.source});

  final SessionMediaAsset asset;
  final _ResourceSource source;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(asset.title),
    ),
    body: Center(
      child: LayoutBuilder(
        builder:
            (context, constraints) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child:
                    kIsWeb
                        ? resource_platform.resourceImage(
                          url: source.url,
                          localPath: source.localPath,
                          fit: BoxFit.contain,
                        )
                        : Hero(
                          tag: 'resource-image-${asset.id}',
                          child: resource_platform.resourceImage(
                            url: source.url,
                            localPath: source.localPath,
                            fit: BoxFit.contain,
                          ),
                        ),
              ),
            ),
      ),
    ),
  );
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    required this.asset,
    required this.repository,
    required this.active,
    required this.onActivate,
  });

  final SessionMediaAsset asset;
  final SessionMediaRepository repository;
  final bool active;
  final VoidCallback onActivate;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  late final Future<_ResourceSource> _source = _resolveSource(
    widget.asset,
    widget.repository,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<_ResourceSource>(
    future: _source,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _ErrorCard(asset: widget.asset);
      if (!snapshot.hasData) return const _LoadingCard(height: 230);
      return Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.active)
              _VideoViewer(source: snapshot.data!)
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: widget.onActivate,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(widget.asset.title),
              subtitle:
                  widget.asset.description?.isNotEmpty == true
                      ? Text(widget.asset.description!)
                      : const Text('Tap play to preview'),
            ),
          ],
        ),
      );
    },
  );
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.source});

  final _ResourceSource source;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialise;
  Timer? _controlsTimer;
  bool _controlsVisible = true;
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    _controller = resource_platform.resourceVideoController(
      url: widget.source.url,
      localPath: widget.source.localPath,
    );
    _initialise = _controller.initialize().then((_) async {
      _controller.addListener(_refresh);
      _showControlsTemporarily();
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialise,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: Icon(Icons.videocam_off_outlined)),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final value = _controller.value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _interactAndTogglePlayback,
        child: AspectRatio(
          aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black, child: VideoPlayer(_controller)),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _interactAndTogglePlayback,
                ),
              ),
              Center(
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IconButton.filled(
                      iconSize: 34,
                      tooltip: value.isPlaying ? 'Pause' : 'Play',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _interactAndTogglePlayback,
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _VideoSeekBar(
                            controller: _controller,
                            onInteraction: _showControlsTemporarily,
                          ),
                          _VideoControlsRow(
                            controller: _controller,
                            onBack:
                                () => _interactAndSeek(
                                  const Duration(seconds: -10),
                                ),
                            onTogglePlayback: _interactAndTogglePlayback,
                            onForward:
                                () => _interactAndSeek(
                                  const Duration(seconds: 10),
                                ),
                            onToggleMute: _toggleMute,
                            onFullScreen: _openFullScreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _togglePlayback() =>
      _controller.value.isPlaying ? _controller.pause() : _controller.play();

  void _interactAndTogglePlayback() {
    _togglePlayback();
    _showControlsTemporarily();
  }

  void _interactAndSeek(Duration change) {
    _seekBy(change);
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _seekBy(Duration change) {
    final duration = _controller.value.duration;
    final target = _controller.value.position + change;
    _controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > duration
          ? duration
          : target,
    );
  }

  void _toggleMute() {
    _volume = _volume == 0 ? 1 : 0;
    _controller.setVolume(_volume);
    _showControlsTemporarily();
    setState(() {});
  }

  Future<void> _openFullScreen() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenVideo(controller: _controller),
      ),
    );
  }
}

class _FullScreenVideo extends StatefulWidget {
  const _FullScreenVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  VideoPlayerController get _controller => widget.controller;
  Timer? _controlsTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _controller.addListener(_refresh);
    _showControlsTemporarily();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.removeListener(_refresh);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _interactAndTogglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio:
                    _controller.value.aspectRatio > 0
                        ? _controller.value.aspectRatio
                        : 16 / 9,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _interactAndTogglePlayback,
            ),
          ),
          Center(
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: IconButton.filled(
                  iconSize: 38,
                  tooltip: _controller.value.isPlaying ? 'Pause' : 'Play',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _interactAndTogglePlayback,
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    color: Colors.white,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _VideoSeekBar(
                        controller: _controller,
                        onInteraction: _showControlsTemporarily,
                      ),
                      _VideoControlsRow(
                        controller: _controller,
                        onBack:
                            () =>
                                _interactAndSeek(const Duration(seconds: -10)),
                        onTogglePlayback: _interactAndTogglePlayback,
                        onForward:
                            () => _interactAndSeek(const Duration(seconds: 10)),
                        onToggleMute: _interactAndToggleMute,
                        onFullScreen: () => Navigator.of(context).pop(),
                        fullScreenIcon: Icons.fullscreen_exit,
                        fullScreenTooltip: 'Exit full screen',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _interactAndTogglePlayback() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
    _showControlsTemporarily();
  }

  void _interactAndSeek(Duration change) {
    _seekBy(change);
    _showControlsTemporarily();
  }

  void _interactAndToggleMute() {
    _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
    _showControlsTemporarily();
  }

  void _seekBy(Duration change) {
    final duration = _controller.value.duration;
    final target = _controller.value.position + change;
    _controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > duration
          ? duration
          : target,
    );
  }
}

class _VideoControlsRow extends StatelessWidget {
  const _VideoControlsRow({
    required this.controller,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onForward,
    required this.onToggleMute,
    this.onFullScreen,
    this.fullScreenIcon = Icons.fullscreen,
    this.fullScreenTooltip = 'Full screen',
  });

  final VideoPlayerController controller;
  final VoidCallback onBack;
  final VoidCallback onTogglePlayback;
  final VoidCallback onForward;
  final VoidCallback onToggleMute;
  final VoidCallback? onFullScreen;
  final IconData fullScreenIcon;
  final String fullScreenTooltip;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '${_format(value.position)} / ${_format(value.duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                color: Colors.white,
                tooltip: 'Back 10 seconds',
                onPressed: onBack,
                icon: const Icon(Icons.replay_10),
              ),
              IconButton.filled(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                onPressed: onTogglePlayback,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                color: Colors.white,
                tooltip: 'Forward 10 seconds',
                onPressed: onForward,
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  color: Colors.white,
                  tooltip: value.volume == 0 ? 'Unmute' : 'Mute',
                  onPressed: onToggleMute,
                  icon: Icon(
                    value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                  ),
                ),
                if (onFullScreen != null)
                  IconButton(
                    tooltip: fullScreenTooltip,
                    color: Colors.white,
                    onPressed: onFullScreen,
                    icon: Icon(fullScreenIcon),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoSeekBar extends StatelessWidget {
  const _VideoSeekBar({required this.controller, required this.onInteraction});

  final VideoPlayerController controller;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    final durationMillis = controller.value.duration.inMilliseconds;
    final maximum = durationMillis > 0 ? durationMillis.toDouble() : 1.0;
    final position = controller.value.position.inMilliseconds.toDouble().clamp(
      0.0,
      maximum,
    );
    return SizedBox(
      height: 40,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        ),
        child: Slider(
          value: position,
          max: maximum,
          onChangeStart: (_) => onInteraction(),
          onChanged: (value) {
            controller.seekTo(Duration(milliseconds: value.round()));
            onInteraction();
          },
        ),
      ),
    );
  }
}

class _PdfCard extends StatefulWidget {
  const _PdfCard({required this.asset, required this.repository});

  final SessionMediaAsset asset;
  final SessionMediaRepository repository;

  @override
  State<_PdfCard> createState() => _PdfCardState();
}

class _PdfCardState extends State<_PdfCard> {
  bool _opening = false;
  bool _downloaded = false;

  String get _fileName => widget.asset.fileName ?? '${widget.asset.title}.pdf';

  @override
  void initState() {
    super.initState();
    unawaited(_checkDownloaded());
  }

  Future<void> _checkDownloaded() async {
    final downloaded = await resource_file_opener.isResourceDownloaded(
      _fileName,
    );
    if (mounted) setState(() => _downloaded = downloaded);
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
      title: Text(widget.asset.title),
      subtitle:
          widget.asset.description?.isNotEmpty == true
              ? Text(widget.asset.description!)
              : null,
      trailing: FilledButton.icon(
        onPressed: _opening ? null : _open,
        icon:
            _opening
                ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(
                  _downloaded
                      ? Icons.folder_open_outlined
                      : Icons.download_outlined,
                ),
        label: Text(
          _opening
              ? 'Opening'
              : _downloaded
              ? 'Open'
              : 'Download',
        ),
      ),
    ),
  );

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final url =
          _downloaded ? '' : await widget.repository.downloadUrl(widget.asset);
      await resource_file_opener.downloadAndOpenResource(
        url: url,
        fileName: _fileName,
      );
      if (mounted) setState(() => _downloaded = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open PDF: $error')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.asset});

  final SessionMediaAsset asset;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(asset.type.icon),
      title: Text(asset.title),
      subtitle: const Text('Preview could not be loaded.'),
    ),
  );
}

class _ResourceSource {
  const _ResourceSource({required this.url, this.localPath});

  final String url;
  final String? localPath;
}

Future<_ResourceSource> _resolveSource(
  SessionMediaAsset asset,
  SessionMediaRepository repository, {
  bool waitForCache = false,
}) async {
  final fileName = asset.fileName ?? '${asset.id}.${asset.type.name}';
  final cacheKey = '${asset.type.name}-${asset.id}-v${asset.version}';
  final cached = await resource_cache.cachedResourcePath(cacheKey, fileName);
  if (cached != null) return _ResourceSource(url: '', localPath: cached);
  final url = await repository.downloadUrl(asset);
  final caching = resource_cache.cacheResource(
    url: url,
    cacheKey: cacheKey,
    fileName: fileName,
  );
  if (waitForCache) {
    final path = await caching;
    return _ResourceSource(url: url, localPath: path);
  }
  unawaited(caching);
  return _ResourceSource(url: url);
}

String _format(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
