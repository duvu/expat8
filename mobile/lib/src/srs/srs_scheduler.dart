import 'dart:math' as math;

import '../models/study_event.dart';
import '../models/vocabulary_word.dart';

/// Spaced-repetition memory of one word for one learner.
///
/// Dart twin of the server scheduler (backend/src/domain/srs.js) so ratings
/// made offline schedule exactly like the server will once they sync;
/// `contracts/srs_vectors.json` pins both implementations.
class SrsMemory {
  const SrsMemory({
    this.reps = 0,
    this.lapses = 0,
    this.ease = defaultEase,
    this.intervalDays = 0,
  });

  static const defaultEase = 2.5;
  static const _minEase = 1.3;
  static const _maxEase = 3.0;
  static const _maxIntervalDays = 365.0;
  static const _masteredIntervalDays = 21.0;
  static const _relearnDelay = Duration(minutes: 10);
  static const _dayMs = 24 * 60 * 60 * 1000;

  /// Successful recalls in a row (reset by a lapse).
  final int reps;

  /// Times the word was forgotten.
  final int lapses;
  final double ease;

  /// Days until the next review; 0 while (re)learning.
  final double intervalDays;

  /// Memory after one [rating]. `tooHard` is a lapse (forgotten: relearn in
  /// 10 minutes); the others are successful recalls growing the interval.
  SrsMemory rate(StudyRating rating) => switch (rating) {
        StudyRating.tooHard => SrsMemory(
            lapses: lapses + 1,
            ease: _round2(math.max(_minEase, ease - 0.2)),
          ),
        StudyRating.hard => _grow(math.max(_minEase, ease - 0.15),
            reps == 0 ? 1 : math.max(1, intervalDays * 1.2)),
        StudyRating.easy => _grow(
            ease,
            switch (reps) {
              0 => 2,
              1 => 6,
              _ => intervalDays * ease,
            }),
        StudyRating.tooEasy => _tooEasy(),
      };

  SrsMemory _tooEasy() {
    final easier = math.min(_maxEase, ease + 0.15);
    return _grow(easier, reps == 0 ? 4 : intervalDays * easier * 1.3);
  }

  SrsMemory _grow(double nextEase, num nextInterval) => SrsMemory(
        reps: reps + 1,
        lapses: lapses,
        ease: _round2(nextEase),
        intervalDays: math.min(_maxIntervalDays, _round2(nextInterval)),
      );

  /// When a word rated at [ratedAt] with this memory is due again.
  DateTime dueAfter(DateTime ratedAt) => intervalDays == 0
      ? ratedAt.add(_relearnDelay)
      : ratedAt.add(Duration(milliseconds: (intervalDays * _dayMs).round()));

  /// learning (being relearned) → review → mastered (three weeks or more).
  WordStatus get status => intervalDays == 0
      ? WordStatus.learning
      : intervalDays >= _masteredIntervalDays
          ? WordStatus.mastered
          : WordStatus.review;

  // Matches JavaScript's Math.round(x * 100) / 100 for the positive values used here.
  static double _round2(num value) => (value * 100).round() / 100;
}
