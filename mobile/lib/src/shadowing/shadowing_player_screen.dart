import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/shadowing_repository.dart';
import '../models/shadowing_video.dart';

/// Full-screen YouTube shadowing player with transcript panel,
/// tap-to-seek, active-line highlight, speed control, seek-back, and loop.
class ShadowingPlayerScreen extends StatefulWidget {
  const ShadowingPlayerScreen({
    required this.video,
    required this.repository,
    super.key,
  });

  final ShadowingVideo video;
  final ShadowingRepository repository;

  @override
  State<ShadowingPlayerScreen> createState() => _ShadowingPlayerScreenState();
}

class _ShadowingPlayerScreenState extends State<ShadowingPlayerScreen> {
  late YoutubePlayerController _ytController;
  late List<ShadowingTranscriptSegment> _segments;
  late ShadowingVideoProgress _progress;

  int _activeSegmentIndex = -1;
  bool _loopActive = false;
  int? _loopSegmentIndex;

  StreamSubscription<YoutubeVideoState>? _stateSubscription;
  StreamSubscription<YoutubePlayerValue>? _valueSubscription;

  static const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _segments = widget.video.segments;
    _progress = widget.repository.loadProgress(widget.video);
    _initPlayer();
  }

  void _initPlayer() {
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: widget.video.providerVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        mute: false,
      ),
    );

    // Track position for active segment highlight and loop.
    _stateSubscription = _ytController.videoStateStream.listen(_onVideoState);

    // Seek to last saved position after player is ready.
    _valueSubscription = _ytController.stream.listen((value) {
      if (value.playerState == PlayerState.cued) {
        final startSec = _progress.lastPositionMs / 1000.0;
        if (startSec > 0) {
          _ytController.seekTo(seconds: startSec, allowSeekAhead: true);
        }
        _applyPlaybackRate(_progress.playbackRate);
      }
    });
  }

  void _onVideoState(YoutubeVideoState state) {
    final posMs = state.position.inMilliseconds;

    // Find active segment.
    int newIndex = -1;
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      if (posMs >= seg.startMs && posMs < seg.endMs) {
        newIndex = i;
        break;
      }
    }

    // Loop active segment.
    if (_loopActive && _loopSegmentIndex != null) {
      final loopSeg = _segments[_loopSegmentIndex!];
      if (posMs >= loopSeg.endMs) {
        _ytController.seekTo(
          seconds: loopSeg.startMs / 1000.0,
          allowSeekAhead: true,
        );
      }
    }

    if (newIndex != _activeSegmentIndex) {
      if (mounted) setState(() => _activeSegmentIndex = newIndex);
    }
  }

  Future<void> _togglePlayPause() async {
    final state = _ytController.value.playerState;
    if (state == PlayerState.playing) {
      await _ytController.pauseVideo();
    } else {
      await _ytController.playVideo();
    }
  }

  Future<void> _seekBack() async {
    final seekBackSec =
        widget.video.playbackDefaults.seekBackMs / 1000.0;
    final state = await _ytController.currentTime;
    final target = (state - seekBackSec).clamp(0.0, double.infinity);
    await _ytController.seekTo(seconds: target, allowSeekAhead: true);
  }

  Future<void> _applyPlaybackRate(double rate) async {
    await _ytController.setPlaybackRate(rate);
    setState(() => _progress = _progress.copyWith(playbackRate: rate));
    widget.repository.saveProgress(
      entryId: widget.video.id,
      lastPositionMs: _progress.lastPositionMs,
      playbackRate: rate,
    );
  }

  void _seekToSegment(int index) {
    final seg = _segments[index];
    _ytController.seekTo(seconds: seg.startMs / 1000.0, allowSeekAhead: true);
    _ytController.playVideo();
  }

  void _toggleLoop(int index) {
    setState(() {
      if (_loopActive && _loopSegmentIndex == index) {
        _loopActive = false;
        _loopSegmentIndex = null;
      } else {
        _loopActive = true;
        _loopSegmentIndex = index;
      }
    });
  }

  Future<void> _saveProgress() async {
    try {
      final posMs =
          ((await _ytController.currentTime) * 1000).round();
      widget.repository.saveProgress(
        entryId: widget.video.id,
        lastPositionMs: posMs,
        playbackRate: _progress.playbackRate,
      );
    } catch (_) {
      // Best-effort save; ignore failures on dispose.
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _valueSubscription?.cancel();
    _saveProgress();
    _ytController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title, overflow: TextOverflow.ellipsis),
        actions: [
          _SpeedButton(
            currentRate: _progress.playbackRate,
            speeds: _speedOptions,
            onSelected: _applyPlaybackRate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: _ytController,
              aspectRatio: 16 / 9,
            ),
          ),
          // Controls
          _PlaybackControls(
            controller: _ytController,
            onPlayPause: _togglePlayPause,
            onSeekBack: _seekBack,
          ),
          // Transcript
          Expanded(
            child: _segments.isEmpty
                ? const Center(child: Text('No transcript available.'))
                : _TranscriptPanel(
                    segments: _segments,
                    activeIndex: _activeSegmentIndex,
                    loopIndex: _loopActive ? _loopSegmentIndex : null,
                    onTap: _seekToSegment,
                    onLongPress: _toggleLoop,
                  ),
          ),
          // Offline note
          const _OfflineNote(),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.onPlayPause,
    required this.onSeekBack,
  });

  final YoutubePlayerController controller;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;

  @override
  Widget build(BuildContext context) {
    return YoutubeValueBuilder(
      controller: controller,
      builder: (ctx, value) {
        final isPlaying = value.playerState == PlayerState.playing;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              tooltip: 'Seek back',
              onPressed: onSeekBack,
            ),
            IconButton(
              iconSize: 48,
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: onPlayPause,
            ),
          ],
        );
      },
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.currentRate,
    required this.speeds,
    required this.onSelected,
  });

  final double currentRate;
  final List<double> speeds;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: currentRate,
      onSelected: onSelected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('${currentRate}x',
            style: Theme.of(context).textTheme.labelLarge),
      ),
      itemBuilder: (_) => speeds
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              child: Text('${s}x'),
            ),
          )
          .toList(),
    );
  }
}

class _TranscriptPanel extends StatefulWidget {
  const _TranscriptPanel({
    required this.segments,
    required this.activeIndex,
    required this.loopIndex,
    required this.onTap,
    required this.onLongPress,
  });

  final List<ShadowingTranscriptSegment> segments;
  final int activeIndex;
  final int? loopIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  @override
  State<_TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<_TranscriptPanel> {
  final _scrollController = ScrollController();
  static const _itemHeight = 56.0;

  @override
  void didUpdateWidget(_TranscriptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex != oldWidget.activeIndex &&
        widget.activeIndex >= 0) {
      _scrollToActive();
    }
  }

  void _scrollToActive() {
    final target = (widget.activeIndex * _itemHeight) -
        (_scrollController.position.viewportDimension / 2) +
        (_itemHeight / 2);
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.segments.length,
      itemExtent: _itemHeight,
      itemBuilder: (ctx, i) {
        final seg = widget.segments[i];
        final isActive = i == widget.activeIndex;
        final isLoop = i == widget.loopIndex;
        return _SegmentTile(
          segment: seg,
          isActive: isActive,
          isLoop: isLoop,
          onTap: () => widget.onTap(i),
          onLongPress: () => widget.onLongPress(i),
        );
      },
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    required this.isActive,
    required this.isLoop,
    required this.onTap,
    required this.onLongPress,
  });

  final ShadowingTranscriptSegment segment;
  final bool isActive;
  final bool isLoop;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isActive
        ? theme.colorScheme.primaryContainer
        : isLoop
            ? theme.colorScheme.secondaryContainer
            : null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 56,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            if (isLoop)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.loop, size: 14),
              ),
            Expanded(
              child: Text(
                segment.text,
                style: isActive
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        'Transcript is available offline. Video playback requires internet.',
        style: Theme.of(context).textTheme.labelSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
