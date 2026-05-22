import 'package:flutter/material.dart';

import '../data/local_database_entities.dart';
import '../speaking/speaking_audio_service.dart';
import '../speaking/speaking_panel.dart';
import '../speaking/speaking_repository.dart';

/// 3-minute speaking drill.
///
/// Selects up to 5 cached prompts from [SpeakingRepository.getDrillCandidates]
/// and walks the user through: listen → record → retry → self-rate.
///
/// Shows an encouraging summary at the end.
/// Handles the empty-state when no cached prompts are available.
class SpeakingDrillScreen extends StatefulWidget {
  const SpeakingDrillScreen({required this.repository, super.key});

  final SpeakingRepository repository;

  @override
  State<SpeakingDrillScreen> createState() => _SpeakingDrillScreenState();
}

class _SpeakingDrillScreenState extends State<SpeakingDrillScreen> {
  late final List<SpeakingPromptEntity> _prompts;
  late final DateTime _sessionStart;
  int _current = 0;
  bool _done = false;
  int _totalAttempts = 0;
  int _totalRetries = 0;

  @override
  void initState() {
    super.initState();
    _prompts = widget.repository.getDrillCandidates(limit: 5);
    _sessionStart = DateTime.now().toUtc();
    widget.repository.beginDrillSession();
    if (_prompts.isNotEmpty) {
      widget.repository.onDrillPromptViewed(_prompts[0]);
    }
  }

  SpeakingPromptEntity get _currentPrompt => _prompts[_current];

  void _onPromptComplete({required int retries}) {
    setState(() {
      _totalAttempts++;
      _totalRetries += retries;
      if (_current < _prompts.length - 1) {
        _current++;
        widget.repository.onDrillPromptViewed(_prompts[_current]);
      } else {
        _done = true;
        final durationMs =
            DateTime.now().toUtc().difference(_sessionStart).inMilliseconds;
        widget.repository.onDrillCompleted(
          promptsAttempted: _totalAttempts,
          promptsCompleted: _totalAttempts,
          totalDurationMs: durationMs,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('3-minute drill'),
        actions: [
          if (!_done && _prompts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_current + 1} / ${_prompts.length}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_prompts.isEmpty) return _emptyState(theme);
    if (_done) return _summary(theme);
    return _drillStep(theme);
  }

  Widget _drillStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: _current / _prompts.length,
            minHeight: 6,
          ),
          const SizedBox(height: 16),
          _DrillPromptCard(
            prompt: _currentPrompt,
            repository: widget.repository,
            onComplete: _onPromptComplete,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No prompts cached yet',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Study a few vocabulary cards first. Speaking prompts will appear here once your device has loaded them.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to learning'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Drill complete!', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'You spoke $_totalAttempts sentence${_totalAttempts == 1 ? '' : 's'}.'
              '${_totalRetries > 0 ? ' You practised again $_totalRetries time${_totalRetries == 1 ? '' : 's'} — great effort!' : ''}',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Every sentence you speak builds real confidence.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single prompt step within the drill.
class _DrillPromptCard extends StatefulWidget {
  const _DrillPromptCard({
    required this.prompt,
    required this.repository,
    required this.onComplete,
  });

  final SpeakingPromptEntity prompt;
  final SpeakingRepository repository;
  final void Function({required int retries}) onComplete;

  @override
  State<_DrillPromptCard> createState() => _DrillPromptCardState();
}

enum _DrillPhase { listen, record, recording, recorded, rated }

class _DrillPromptCardState extends State<_DrillPromptCard> {
  _DrillPhase _phase = _DrillPhase.listen;
  String? _attemptId;
  int _retries = 0;
  bool _permDenied = false;

  String get _targetText => widget.prompt.targetText ?? '';
  String? get _viHint => widget.prompt.viHint;
  String get _promptId => widget.prompt.promptId;

  Future<void> _onListen() async {
    await widget.repository.playSample(_targetText);
    widget.repository.onDrillSamplePlayed(widget.prompt);
    setState(() => _phase = _DrillPhase.record);
  }

  Future<void> _onRecord() async {
    final status = await widget.repository.requestMicPermission();
    if (status == MicPermissionStatus.permanentlyDenied) {
      setState(() => _permDenied = true);
      return;
    }
    if (status != MicPermissionStatus.granted) return;
    setState(() => _phase = _DrillPhase.recording);
    final id =
        await widget.repository.startDrillRecording(promptId: _promptId);
    setState(() => _attemptId = id);
  }

  Future<void> _onStop() async {
    await widget.repository.stopDrillRecording(promptId: _promptId);
    setState(() => _phase = _DrillPhase.recorded);
  }

  void _onRetry() {
    _retries++;
    final id = _attemptId;
    if (id != null) {
      widget.repository.onDrillRetried(
        attemptId: id,
        promptId: _promptId,
        retryCount: _retries,
      );
    }
    setState(() => _phase = _DrillPhase.record);
  }

  void _onRate(SpeakingDrillRating rating) {
    final id = _attemptId;
    if (id != null) {
      widget.repository.onDrillSelfRated(
        attemptId: id,
        promptId: _promptId,
        rating: rating,
      );
    }
    setState(() => _phase = _DrillPhase.rated);
  }

  void _onNext() {
    widget.onComplete(retries: _retries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_targetText,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (_viHint != null) ...[
              const SizedBox(height: 4),
              Text(_viHint!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.secondary)),
            ],
            const SizedBox(height: 16),
            if (_permDenied)
              Text('Microphone access required.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error))
            else
              _controls(theme),
          ],
        ),
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    return switch (_phase) {
      _DrillPhase.listen => FilledButton.icon(
          onPressed: _onListen,
          icon: const Icon(Icons.volume_up_outlined),
          label: const Text('Listen first'),
        ),
      _DrillPhase.record => FilledButton.icon(
          onPressed: _onRecord,
          icon: const Icon(Icons.mic),
          label: const Text('Record'),
        ),
      _DrillPhase.recording => FilledButton.icon(
          onPressed: _onStop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error),
        ),
      _DrillPhase.recorded => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            Text('How did that feel?', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: SpeakingDrillRating.values.map((r) {
                return OutlinedButton(
                  onPressed: () => _onRate(r),
                  child: Text(r.label),
                );
              }).toList(),
            ),
          ],
        ),
      _DrillPhase.rated => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _retries == 0
                  ? 'Well done!'
                  : 'Great persistence — $_retries extra attempt${_retries == 1 ? '' : 's'}!',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _onNext,
              child: const Text('Next'),
            ),
          ],
        ),
    };
  }
}
