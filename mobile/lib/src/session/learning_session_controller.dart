import 'package:flutter/foundation.dart';

import '../data/word_repository.dart';
import '../models/study_event.dart';
import '../models/vocabulary_word.dart';
import '../telemetry.dart';
import 'card_selection.dart';

class LearningSessionController extends ChangeNotifier {
  LearningSessionController({
    required this.repository,
    CardSelectionWindow? selectionWindow,
    TelemetrySink? telemetry,
  })  : _selectionWindow = selectionWindow ?? CardSelectionWindow(),
        _telemetry = telemetry ?? DebugTelemetrySink();

  final WordRepository repository;
  final CardSelectionWindow _selectionWindow;
  final TelemetrySink _telemetry;

  VocabularyWord? currentWord;
  bool isLoading = false;
  String? statusMessage;

  Future<void> loadInitial() async {
    await nextCard();
  }

  Future<void> nextCard() async {
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final now = DateTime.now().toUtc();
    final excludedServerWordId = currentWord?.serverWordId;
    final preferred = _selectionWindow.preferredKind();
    VocabularyWord? word;
    CardKind? actualKind;

    if (preferred == CardKind.newWord) {
      _telemetry.track(TelemetryEvent.newWordRequested);
      word = await repository.getNewWordWithFallback(
        excludeServerWordId: excludedServerWordId,
      );
      actualKind = word == null ? null : CardKind.newWord;
      word ??= await repository.getReviewWord(now);
      actualKind ??= word == null ? null : CardKind.review;
    } else {
      word = await repository.getReviewWord(now);
      actualKind = word == null ? null : CardKind.review;
      word ??= await repository.getNewWordWithFallback(
        excludeServerWordId: excludedServerWordId,
      );
      actualKind ??= word == null ? null : CardKind.newWord;
    }

    if (word == null) {
      statusMessage = 'No local learning card is available.';
    } else {
      currentWord = word;
      _selectionWindow.record(actualKind!);
      _telemetry.track(
        actualKind == CardKind.newWord
            ? TelemetryEvent.cardShown
            : TelemetryEvent.reviewWordShown,
        {'word_id': word.serverWordId ?? word.localId},
      );
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> rateCurrent(StudyRating rating) async {
    final word = currentWord;
    if (word == null) {
      return;
    }
    await repository.recordRating(
      word: word,
      rating: rating,
      now: DateTime.now().toUtc(),
    );
    _telemetry.track(TelemetryEvent.studyRatingSubmitted, {
      'rating': rating.name,
      'word_id': word.serverWordId ?? word.localId,
    });
    await nextCard();
  }
}
