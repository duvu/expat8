import 'package:flutter/material.dart';

import '../models/vocabulary_word.dart';
import 'speaking_audio_service.dart';
import 'speaking_repository.dart';

/// Displays the speaking panel for a vocabulary card.
///
/// Shows target sentence + Vietnamese hint, record/playback controls,
/// retry, and a self-rating row. Does NOT block the swipe-based card
/// navigation — it is rendered as an expandable section within the card.
class SpeakingPanel extends StatefulWidget {
  const SpeakingPanel({
    required this.word,
    required this.repository,
    super.key,
  });

  final VocabularyWord word;
  final SpeakingRepository repository;

  @override
  State<SpeakingPanel> createState() => _SpeakingPanelState();
}

enum _PanelPhase { idle, recording, recorded, rated }

class _SpeakingPanelState extends State<SpeakingPanel> {
  _PanelPhase _phase = _PanelPhase.idle;
  bool _playing = false;
  String? _currentAttemptId;
  String? _localAudioPath;
  SpeakingRating? _selfRating;
  int _retryCount = 0;
  bool _permDenied = false;

  SpeakingPrompt? get _prompt => widget.word.speakingPrompt;

  String get _targetText =>
      _prompt?.targetText ?? widget.word.example;

  String? get _viHint => _prompt?.viHint ?? widget.word.exampleVi;

  @override
  void initState() {
    super.initState();
    // Log that user viewed the prompt.
    widget.repository.onPromptViewed(widget.word);
  }

  // ---- helpers ----

  Future<void> _onPlaySample() async {
    widget.repository.onSamplePlayed(widget.word);
    await widget.repository.playSample(_targetText);
    setState(() => _playing = false);
  }

  Future<void> _onRecord() async {
    final status = await widget.repository.requestMicPermission();
    if (status == MicPermissionStatus.permanentlyDenied) {
      setState(() => _permDenied = true);
      return;
    }
    if (status != MicPermissionStatus.granted) return;

    setState(() => _phase = _PanelPhase.recording);
    _currentAttemptId = await widget.repository.startRecording(widget.word);
  }

  Future<void> _onStopRecording() async {
    await widget.repository.stopRecording(widget.word);
    setState(() => _phase = _PanelPhase.recorded);
  }

  Future<void> _onPlayBack() async {
    final path = _localAudioPath;
    if (path == null) return;
    setState(() => _playing = true);
    await widget.repository.playLocalRecording(path);
    setState(() => _playing = false);
  }

  Future<void> _onRetry() async {
    final id = _currentAttemptId;
    if (id != null) {
      widget.repository.onRetried(widget.word, id);
      _retryCount++;
    }
    setState(() {
      _phase = _PanelPhase.idle;
      _selfRating = null;
      _localAudioPath = null;
    });
    await _onRecord();
  }

  void _onRate(SpeakingRating rating) {
    final id = _currentAttemptId;
    if (id == null) return;
    widget.repository.onSelfRated(widget.word, id, rating);
    setState(() {
      _selfRating = rating;
      _phase = _PanelPhase.rated;
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _privacyNote(theme),
          const SizedBox(height: 8),
          _targetRow(theme),
          if (_viHint != null) ...[
            const SizedBox(height: 4),
            Text(
              _viHint!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.secondary),
            ),
          ],
          if (_prompt?.pronunciationTip != null) ...[
            const SizedBox(height: 4),
            Text(
              'Tip: ${_prompt!.pronunciationTip}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (_permDenied) _permDeniedBanner(theme),
          if (!_permDenied) _controls(theme),
          if (_phase == _PanelPhase.rated) _completionCopy(theme),
        ],
      ),
    );
  }

  Widget _privacyNote(ThemeData theme) {
    return Text(
      'Your recording stays private on this device.',
      style: theme.textTheme.labelSmall
          ?.copyWith(color: theme.colorScheme.outline),
    );
  }

  Widget _targetRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _targetText,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.volume_up_outlined),
          tooltip: 'Listen',
          onPressed: () {
            setState(() => _playing = true);
            _onPlaySample();
          },
        ),
      ],
    );
  }

  Widget _controls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_phase == _PanelPhase.idle) ...[
          FilledButton.icon(
            onPressed: _onRecord,
            icon: const Icon(Icons.mic),
            label: const Text('Record'),
          ),
        ],
        if (_phase == _PanelPhase.recording) ...[
          FilledButton.icon(
            onPressed: _onStopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
          ),
        ],
        if (_phase == _PanelPhase.recorded ||
            _phase == _PanelPhase.rated) ...[
          Row(
            children: [
              IconButton(
                icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                tooltip: 'Play your recording',
                onPressed: _playing ? null : _onPlayBack,
              ),
              TextButton.icon(
                onPressed: _onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(
                    'Retry${_retryCount > 0 ? ' (${_retryCount + 1}x)' : ''}'),
              ),
            ],
          ),
          if (_phase == _PanelPhase.recorded) ...[
            const SizedBox(height: 8),
            Text('How did that feel?',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            _ratingRow(),
          ],
        ],
      ],
    );
  }

  Widget _ratingRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: SpeakingRating.values.map((r) {
        final label = switch (r) {
          SpeakingRating.easy => 'Easy',
          SpeakingRating.ok => 'OK',
          SpeakingRating.hard => 'Hard',
        };
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton(
            onPressed: () => _onRate(r),
            child: Text(label),
          ),
        );
      }).toList(),
    );
  }

  Widget _completionCopy(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        _retryCount == 0
            ? 'Great — you spoke it! Every attempt builds fluency.'
            : 'You practiced $_retryCount more time${_retryCount == 1 ? '' : 's'} — that persistence pays off!',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _permDeniedBanner(ThemeData theme) {
    return Text(
      'Microphone access is required to record. Enable it in Settings.',
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.error),
    );
  }
}
