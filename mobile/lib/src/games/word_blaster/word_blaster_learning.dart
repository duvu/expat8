import 'dart:async';

import '../../data/word_repository.dart';
import '../../logging/logger.dart';
import 'word_blaster_session.dart';

/// Turns Word Blaster answers into study events (one per word per round) and
/// syncs them in the background when possible.
class WordBlasterLearning {
  WordBlasterLearning(
      {required this.repository, this.logger = const NoopLogger()});

  static const source = 'game_word_blaster';
  static const reviewSource = 'game_word_blaster_review';

  final WordRepository repository;
  final Logger logger;
  final List<Future<void>> _pending = [];

  void record(WordOutcome outcome) {
    final future = repository
        .recordPracticeAnswer(
          word: outcome.word,
          correct: outcome.correct,
          source: source,
        )
        .catchError((Object error) => logger.warning(
              category: AppLogCategory.session,
              event: 'game.study_event_failed',
              message: 'Could not record a Word Blaster answer.',
              context: {'error': '$error'},
            ));
    _pending.add(future);
  }

  /// Waits for local writes, then tries to upload them (offline-safe).
  Future<void> finishRound() async {
    await Future.wait(_pending);
    _pending.clear();
    unawaited(() async {
      try {
        await repository.syncPendingEvents(
          deviceId: await repository.getOrCreateDeviceId(),
        );
      } on Object {
        // Stays queued for the regular sync cycle.
      }
    }());
  }

  /// A learner flagged a question as wrong (bad distractor, bad translation).
  Future<void> reportQuestion({
    required String term,
    required String prompt,
    required List<String> options,
    String? note,
  }) =>
      logger.warning(
        category: AppLogCategory.session,
        event: 'game.question_reported',
        message: 'Learner reported a Word Blaster question.',
        context: {
          'term': term,
          'prompt': prompt,
          'options': options.join(' | '),
          if (note != null) 'note': note,
        },
      );
}
