import 'dart:math';

import '../data/local_database_entities.dart';
import '../data/memorization_repository.dart';
import '../models/memorization_passage.dart';

/// Rating a user gives after a drill exercise.
enum DrillRating {
  /// User recalled correctly with ease — extend interval.
  easy,

  /// User recalled but with effort — small interval extension.
  hard,

  /// User failed to recall — relearn immediately in session.
  again,
}

/// Phase within a single segment's drill cycle.
enum DrillPhase {
  /// User is reading the full segment text before recall.
  reading,

  /// User is performing a recall exercise.
  recall,

  /// Session complete — all segments reviewed.
  done,
}

/// Type of recall exercise presented to the user.
enum ExerciseType {
  /// Show first 3-5 words; user recites rest mentally, then reveals.
  fullRecall,

  /// Segment displayed with 1-3 key phrases blanked; tap each to reveal.
  cloze,

  /// Show previous segment's last sentence; user predicts current; then reveals.
  nextSegmentPrediction,
}

/// Manages a single drill session for a passage.
///
/// A session proceeds segment-by-segment through the un-mastered segments.
/// For each segment the controller cycles through [reading] → [recall] phases
/// and applies SRS updates when the user rates their performance.
///
/// Callers must save progress by observing [currentProgress] after each call
/// to [rate] or [advanceToReading].
class MemorizationDrillController {
  MemorizationDrillController({
    required this.passageId,
    required this.segments,
    required this.repository,
    required List<LocalSegmentProgressEntity> initialProgress,
    DateTime? nowOverride,
  })  : _progressMap = {for (final p in initialProgress) p.segmentId: p},
        _nowOverride = nowOverride {
    _buildQueue();
    _advanceQueue();
  }

  final String passageId;

  /// Ordered list of all passage segments.
  final List<MemorizationSegment> segments;

  final MemorizationRepository repository;

  final Map<String, LocalSegmentProgressEntity> _progressMap;
  final DateTime? _nowOverride;

  // Ordered list of segment indices to drill (un-mastered first, then due).
  final List<int> _queue = [];
  int _queueIndex = -1;

  // Within-segment exercise rotation index.
  int _exerciseIndex = 0;

  DrillPhase _phase = DrillPhase.reading;
  int? _currentSegmentIndex;

  // ---------------------------------------------------------------------------
  // Public state accessors
  // ---------------------------------------------------------------------------

  DrillPhase get phase => _phase;

  /// Index into [segments] for the segment currently being drilled.
  int? get currentSegmentIndex => _currentSegmentIndex;

  MemorizationSegment? get currentSegment =>
      _currentSegmentIndex != null ? segments[_currentSegmentIndex!] : null;

  /// The previous segment (for next-segment-prediction exercise), or null.
  MemorizationSegment? get previousSegment {
    if (_currentSegmentIndex == null || _currentSegmentIndex! == 0) return null;
    return segments[_currentSegmentIndex! - 1];
  }

  ExerciseType get currentExerciseType {
    final types = _availableExerciseTypes;
    return types[_exerciseIndex % types.length];
  }

  LocalSegmentProgressEntity? get currentProgress {
    final seg = currentSegment;
    if (seg == null) return null;
    return _progressMap[seg.id];
  }

  /// Progress summary: how many segments are in review/mastered.
  int get masteredCount => _progressMap.values
      .where((p) => p.status == 'review' || p.status == 'mastered')
      .length;

  int get totalSegments => segments.length;

  // ---------------------------------------------------------------------------
  // Session control
  // ---------------------------------------------------------------------------

  /// Moves from [recall] back to [reading] for the same segment (e.g. "again").
  void advanceToReading() {
    _phase = DrillPhase.reading;
  }

  /// Moves from [reading] to [recall].
  void startRecall() {
    if (_phase == DrillPhase.reading) {
      _phase = DrillPhase.recall;
    }
  }

  /// Advances to the next exercise within the same segment's recall phase.
  void nextExercise() {
    _exerciseIndex++;
  }

  /// Applies an SRS rating for the current segment.
  ///
  /// Returns the updated [LocalSegmentProgressEntity] (already stored in
  /// [_progressMap]; callers should persist it via [repository]).
  LocalSegmentProgressEntity rate(DrillRating rating) {
    final seg = currentSegment!;
    final now = _now();
    final existing = _progressMap[seg.id];
    final updated = _applyRating(
      existing: existing,
      segmentId: seg.id,
      rating: rating,
      now: now,
    );
    _progressMap[seg.id] = updated;

    if (rating == DrillRating.again) {
      // Re-queue this segment at the end of the session.
      _queue.add(_currentSegmentIndex!);
    }

    // Advance to next segment.
    _exerciseIndex = 0;
    _advanceQueue();

    return updated;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  DateTime _now() => _nowOverride ?? DateTime.now().toUtc();

  List<ExerciseType> get _availableExerciseTypes {
    final idx = _currentSegmentIndex;
    if (idx != null && idx > 0) {
      return [
        ExerciseType.fullRecall,
        ExerciseType.cloze,
        ExerciseType.nextSegmentPrediction,
      ];
    }
    // First segment: no previous segment for prediction.
    return [ExerciseType.fullRecall, ExerciseType.cloze];
  }

  void _buildQueue() {
    final now = _now().millisecondsSinceEpoch;

    // 1. Un-studied segments (status == 'new'), in order.
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final prog = _progressMap[seg.id];
      if (prog == null || prog.status == 'new') {
        _queue.add(i);
      }
    }

    // 2. Due segments (status != 'mastered', nextReviewAt <= now), by dueDate.
    final due = <(int, int)>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final prog = _progressMap[seg.id];
      if (prog != null &&
          prog.status != 'new' &&
          prog.status != 'mastered' &&
          (prog.nextReviewAtMs ?? 0) <= now) {
        due.add((i, prog.nextReviewAtMs ?? 0));
      }
    }
    due.sort((a, b) => a.$2.compareTo(b.$2));
    _queue.addAll(due.map((e) => e.$1));

    // De-duplicate while preserving order.
    final seen = <int>{};
    _queue.retainWhere(seen.add);
  }

  void _advanceQueue() {
    _queueIndex++;
    if (_queueIndex < _queue.length) {
      _currentSegmentIndex = _queue[_queueIndex];
      _phase = DrillPhase.reading;
    } else {
      _currentSegmentIndex = null;
      _phase = DrillPhase.done;
    }
  }

  LocalSegmentProgressEntity _applyRating({
    required LocalSegmentProgressEntity? existing,
    required String segmentId,
    required DrillRating rating,
    required DateTime now,
  }) {
    final nowMs = now.millisecondsSinceEpoch;
    final reviewCount = (existing?.reviewCount ?? 0) + 1;
    final easeFactor = _newEaseFactor(
        existing?.easeFactor ?? 2.5, rating);
    final intervalDays = _newInterval(
      currentInterval: existing?.intervalDays ?? 0.0,
      easeFactor: easeFactor,
      rating: rating,
    );
    final nextReviewAtMs = rating == DrillRating.again
        ? now.add(const Duration(minutes: 1)).millisecondsSinceEpoch
        : now
            .add(Duration(
                milliseconds: (intervalDays * Duration.millisecondsPerDay)
                    .round()))
            .millisecondsSinceEpoch;
    final status = _newStatus(
      current: existing?.status ?? 'new',
      reviewCount: reviewCount,
      rating: rating,
      existing: existing,
    );

    return LocalSegmentProgressEntity(
      id: existing?.id ?? 0,
      segmentId: segmentId,
      passageId: passageId,
      status: status,
      reviewCount: reviewCount,
      easeFactor: easeFactor,
      intervalDays: intervalDays,
      lastReviewedAtMs: nowMs,
      nextReviewAtMs: nextReviewAtMs,
      isDirty: 1,
    );
  }

  double _newEaseFactor(double current, DrillRating rating) {
    // SM-2-style ease factor adjustment.
    const delta = {
      DrillRating.easy: 0.15,
      DrillRating.hard: -0.15,
      DrillRating.again: -0.2,
    };
    return max(1.3, current + (delta[rating] ?? 0.0));
  }

  double _newInterval({
    required double currentInterval,
    required double easeFactor,
    required DrillRating rating,
  }) {
    if (rating == DrillRating.again) return 0.0;
    final base = currentInterval <= 0 ? 1.0 : currentInterval;
    return switch (rating) {
      DrillRating.easy => base * easeFactor * 1.5,
      DrillRating.hard => base * easeFactor * 0.8,
      DrillRating.again => 0.0,
    };
  }

  String _newStatus({
    required String current,
    required int reviewCount,
    required DrillRating rating,
    required LocalSegmentProgressEntity? existing,
  }) {
    if (rating == DrillRating.again) return 'learning';
    if (current == 'new' || current == 'learning') {
      if (rating == DrillRating.easy) return 'review';
      return 'learning';
    }
    if (current == 'review') {
      // Mastered: 5+ reviews, no 'again' in last 3 (simplification: check
      // review_count threshold here; deeper history tracking not stored).
      if (reviewCount >= 5) return 'mastered';
      return 'review';
    }
    // Already mastered — keep mastered.
    return current;
  }
}
