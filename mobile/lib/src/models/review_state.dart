import 'vocabulary_word.dart';

/// The server's spaced-repetition state of one word for the signed-in
/// learner (or this device when signed out); see `GET /v1/review/states`.
class ServerReviewState {
  const ServerReviewState({
    required this.word,
    required this.status,
    required this.nextReviewAt,
    required this.lastStudiedAt,
    required this.ease,
    required this.intervalDays,
    required this.reps,
    required this.lapses,
  });

  factory ServerReviewState.fromJson(Map<String, dynamic> json) {
    final state = json['state'] as Map<String, dynamic>;
    DateTime? time(String key) =>
        DateTime.tryParse(state[key] as String? ?? '')?.toUtc();
    return ServerReviewState(
      word: VocabularyWord.fromJson(json['word'] as Map<String, dynamic>),
      status: switch (state['status']) {
        'learning' => WordStatus.learning,
        'review' => WordStatus.review,
        _ => WordStatus.mastered, // 'mastered' (and legacy 'completed')
      },
      nextReviewAt: time('next_review_at'),
      lastStudiedAt: time('last_studied_at'),
      ease: (state['ease'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (state['interval_days'] as num?)?.toDouble() ?? 0,
      reps: (state['reps'] as num?)?.toInt() ?? 0,
      lapses: (state['lapses'] as num?)?.toInt() ?? 0,
    );
  }

  final VocabularyWord word;
  final WordStatus status;
  final DateTime? nextReviewAt;
  final DateTime? lastStudiedAt;
  final double ease;
  final double intervalDays;
  final int reps;
  final int lapses;
}

class ReviewStatesPage {
  const ReviewStatesPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ServerReviewState> items;

  /// Where the next pull continues from; always worth storing.
  final String? nextCursor;
  final bool hasMore;
}
