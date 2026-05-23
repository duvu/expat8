import 'dart:math';

import 'package:flutter/material.dart';

import '../data/local_database_entities.dart';
import '../data/memorization_drill_controller.dart';
import '../data/memorization_repository.dart';
import '../models/memorization_passage.dart';
import '../models/user_session.dart';

/// Entry point for a memorization drill session.
///
/// Loads segments + local progress, constructs a [MemorizationDrillController],
/// and drives the reading → recall → next-segment flow.
class MemorizationDrillScreen extends StatefulWidget {
  const MemorizationDrillScreen({
    super.key,
    required this.passage,
    required this.repository,
    required this.userSession,
  });

  final MemorizationPassage passage;
  final MemorizationRepository repository;
  final UserSession userSession;

  @override
  State<MemorizationDrillScreen> createState() =>
      _MemorizationDrillScreenState();
}

class _MemorizationDrillScreenState extends State<MemorizationDrillScreen> {
  MemorizationDrillController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initDrill();
  }

  Future<void> _initDrill() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Ensure segment content is cached.
      final passage = await widget.repository.getPassage(
        sessionToken: widget.userSession.sessionToken,
        passageId: widget.passage.id,
      );
      final segments = passage.segments ?? [];
      if (segments.isEmpty) {
        setState(() {
          _errorMessage =
              'No segments available. The passage may still be processing.';
          _isLoading = false;
        });
        return;
      }

      // Load local progress.
      final progress = widget.repository
          .getPassageProgressLocalAll(widget.passage.id);

      final controller = MemorizationDrillController(
        passageId: widget.passage.id,
        segments: segments,
        repository: widget.repository,
        initialProgress: progress,
      );

      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start drill: $e';
        _isLoading = false;
      });
    }
  }

  void _onReady() {
    setState(() => _controller!.startRecall());
  }

  void _onRate(DrillRating rating) {
    final updated = _controller!.rate(rating);
    // Persist progress locally (sync to backend happens in background).
    widget.repository.saveSegmentProgressLocal(updated);
    setState(() {});
    _scheduleSyncDirty();
  }

  void _onNextExercise() {
    setState(() => _controller!.nextExercise());
  }

  void _scheduleSyncDirty() {
    // Fire-and-forget background sync. Errors are silently ignored here;
    // data remains local until next successful sync.
    widget.repository
        .syncDirtyProgress(sessionToken: widget.userSession.sessionToken)
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.passage.title),
        bottom: _controller != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _controller!.totalSegments > 0
                      ? _controller!.masteredCount /
                          _controller!.totalSegments
                      : 0,
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center),
                  ),
                )
              : _buildDrillBody(),
    );
  }

  Widget _buildDrillBody() {
    final ctrl = _controller!;
    if (ctrl.phase == DrillPhase.done) {
      return _DrillCompleteView(
        masteredCount: ctrl.masteredCount,
        totalSegments: ctrl.totalSegments,
        onClose: () => Navigator.pop(context),
      );
    }

    final segment = ctrl.currentSegment!;

    if (ctrl.phase == DrillPhase.reading) {
      return _ReadingPhaseView(
        segment: segment,
        progress: ctrl.currentProgress,
        onReady: _onReady,
      );
    }

    // Recall phase.
    return switch (ctrl.currentExerciseType) {
      ExerciseType.fullRecall => _FullRecallExercise(
          segment: segment,
          onRate: _onRate,
        ),
      ExerciseType.cloze => _ClozeExercise(
          segment: segment,
          onRate: _onRate,
        ),
      ExerciseType.nextSegmentPrediction => _NextSegmentPredictionExercise(
          previousSegment: ctrl.previousSegment,
          currentSegment: segment,
          onRate: _onRate,
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Reading phase
// ---------------------------------------------------------------------------

class _ReadingPhaseView extends StatelessWidget {
  const _ReadingPhaseView({
    required this.segment,
    required this.progress,
    required this.onReady,
  });

  final MemorizationSegment segment;
  final LocalSegmentProgressEntity? progress;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, progress?.status ?? 'new');
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chip
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  progress?.status ?? 'new',
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Segment ${segment.position + 1}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Full text
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                segment.text,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReady,
              icon: const Icon(Icons.check),
              label: const Text('Ready — start recall'),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    return switch (status) {
      'learning' => Colors.orange,
      'review' => Colors.blue,
      'mastered' => Colors.green,
      _ => Colors.grey,
    };
  }
}

// ---------------------------------------------------------------------------
// Full recall exercise (10.3)
// ---------------------------------------------------------------------------

class _FullRecallExercise extends StatefulWidget {
  const _FullRecallExercise({
    required this.segment,
    required this.onRate,
  });

  final MemorizationSegment segment;
  final void Function(DrillRating) onRate;

  @override
  State<_FullRecallExercise> createState() => _FullRecallExerciseState();
}

class _FullRecallExerciseState extends State<_FullRecallExercise> {
  bool _revealed = false;

  /// First 3-5 words as a prompt.
  String get _prompt {
    final words = widget.segment.text.trim().split(RegExp(r'\s+'));
    final count = words.length < 5 ? words.length : 5;
    return '${words.sublist(0, count).join(' ')}…';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Full recall',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Complete the segment:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          // Prompt
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _prompt,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 16),
          if (_revealed) ...[
            // Full text revealed
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.segment.text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.7),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _RatingButtons(onRate: widget.onRate),
          ] else ...[
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility),
                label: const Text('Reveal'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cloze deletion exercise (10.4)
// ---------------------------------------------------------------------------

class _ClozeExercise extends StatefulWidget {
  const _ClozeExercise({
    required this.segment,
    required this.onRate,
  });

  final MemorizationSegment segment;
  final void Function(DrillRating) onRate;

  @override
  State<_ClozeExercise> createState() => _ClozeExerciseState();
}

class _ClozeExerciseState extends State<_ClozeExercise> {
  late final List<_ClozeItem> _items;
  bool _allRevealed = false;

  @override
  void initState() {
    super.initState();
    _items = _buildClozeItems(widget.segment.text);
  }

  /// Splits text into runs of normal text and blanked phrases.
  List<_ClozeItem> _buildClozeItems(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length < 6) {
      // Too short for cloze — blank one phrase in the middle.
      return [
        _ClozeItem(text: words.sublist(0, words.length ~/ 2).join(' ')),
        _ClozeItem(
            text: words.sublist(words.length ~/ 2).join(' '), isCloze: true),
      ];
    }
    // Pick 2 non-adjacent key phrases (runs of 2-3 words).
    final items = <_ClozeItem>[];
    final rand = Random(text.hashCode);
    final blankStarts = <int>{};

    void pickBlank() {
      for (var attempt = 0; attempt < 20; attempt++) {
        final start = rand.nextInt(words.length - 2);
        if (blankStarts.any((b) => (b - start).abs() < 4)) continue;
        blankStarts.add(start);
        break;
      }
    }

    pickBlank();
    pickBlank();

    int cursor = 0;
    final sorted = blankStarts.toList()..sort();
    for (final start in sorted) {
      if (cursor < start) {
        items.add(_ClozeItem(text: words.sublist(cursor, start).join(' ')));
      }
      final end = (start + 2).clamp(0, words.length);
      items.add(_ClozeItem(text: words.sublist(start, end).join(' '), isCloze: true));
      cursor = end;
    }
    if (cursor < words.length) {
      items.add(_ClozeItem(text: words.sublist(cursor).join(' ')));
    }
    return items;
  }

  void _reveal(int index) {
    setState(() {
      _items[index].revealed = true;
      _allRevealed = _items.every((i) => !i.isCloze || i.revealed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cloze',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Tap the blanks to reveal:',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                runSpacing: 4,
                spacing: 4,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _ClozeChip(
                      item: _items[i],
                      onTap: _items[i].isCloze && !_items[i].revealed
                          ? () => _reveal(i)
                          : null,
                    ),
                ],
              ),
            ),
          ),
          if (_allRevealed) ...[
            const SizedBox(height: 16),
            _RatingButtons(onRate: widget.onRate),
          ],
        ],
      ),
    );
  }
}

class _ClozeItem {
  _ClozeItem({required this.text, this.isCloze = false, this.revealed = false});
  final String text;
  final bool isCloze;
  bool revealed;
}

class _ClozeChip extends StatelessWidget {
  const _ClozeChip({required this.item, this.onTap});

  final _ClozeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!item.isCloze) {
      return Text(item.text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7));
    }
    if (item.revealed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(item.text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  height: 1.7,
                )),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '_ ' * (item.text.split(' ').length.clamp(1, 5)),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              letterSpacing: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Next-segment prediction exercise (10.5)
// ---------------------------------------------------------------------------

class _NextSegmentPredictionExercise extends StatefulWidget {
  const _NextSegmentPredictionExercise({
    required this.previousSegment,
    required this.currentSegment,
    required this.onRate,
  });

  final MemorizationSegment? previousSegment;
  final MemorizationSegment currentSegment;
  final void Function(DrillRating) onRate;

  @override
  State<_NextSegmentPredictionExercise> createState() =>
      _NextSegmentPredictionExerciseState();
}

class _NextSegmentPredictionExerciseState
    extends State<_NextSegmentPredictionExercise> {
  bool _revealed = false;

  /// Last sentence of the previous segment.
  String get _previousEnding {
    if (widget.previousSegment == null) return '';
    final text = widget.previousSegment!.text.trim();
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.isNotEmpty ? sentences.last : text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Predict next',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('What comes after?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (widget.previousSegment != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '…${_previousEnding}',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 16),
          if (_revealed) ...[
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.currentSegment.text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.7),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _RatingButtons(onRate: widget.onRate),
          ] else ...[
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility),
                label: const Text('Reveal'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared rating buttons (10.6 — SRS rating)
// ---------------------------------------------------------------------------

class _RatingButtons extends StatelessWidget {
  const _RatingButtons({required this.onRate});

  final void Function(DrillRating) onRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () => onRate(DrillRating.again),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400),
            child: const Text('Again'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onRate(DrillRating.hard),
            child: const Text('Hard'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: () => onRate(DrillRating.easy),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600),
            child: const Text('Easy'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Session complete (10.8)
// ---------------------------------------------------------------------------

class _DrillCompleteView extends StatelessWidget {
  const _DrillCompleteView({
    required this.masteredCount,
    required this.totalSegments,
    required this.onClose,
  });

  final int masteredCount;
  final int totalSegments;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final allMastered = masteredCount >= totalSegments;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allMastered ? Icons.emoji_events : Icons.check_circle_outline,
              size: 72,
              color: allMastered ? Colors.amber : Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              allMastered ? 'Passage mastered!' : 'Session complete',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '$masteredCount / $totalSegments segments in review or mastered',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onClose,
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
