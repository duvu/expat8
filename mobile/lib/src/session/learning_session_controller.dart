import 'package:flutter/foundation.dart';

import '../data/word_repository.dart';
import '../models/proficiency_state.dart';
import '../models/study_event.dart';
import '../models/user_session.dart';
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
  ProficiencyState proficiency = ProficiencyState.initial();
  UserSession? userSession;
  String? _deviceId;
  String? _levelChangeMessage;

  String? takeLevelChangeMessage() {
    final message = _levelChangeMessage;
    _levelChangeMessage = null;
    return message;
  }

  Future<void> loadInitial() async {
    _deviceId ??= await repository.getOrCreateDeviceId();
    userSession = await repository.loadUserSession();
    try {
      proficiency = await repository.fetchProficiency(deviceId: _deviceId!);
    } catch (_) {
      proficiency = ProficiencyState.initial();
    }
    await showNewWord();
  }

  Future<void> nextCard() async {
    await showNewWord();
  }

  Future<void> showNewWord() async {
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final now = DateTime.now().toUtc();
    final excludedServerWordId = currentWord?.serverWordId;
    VocabularyWord? word;
    CardKind? actualKind;

    _telemetry.track(TelemetryEvent.newWordRequested);
    _telemetry.track(TelemetryEvent.newWordSwipeRequested);
    word = await repository.getNewWordWithFallback(
      excludeServerWordId: excludedServerWordId,
      proficiencyLevel: proficiency.level,
      deviceId: _deviceId,
    );
    actualKind = word == null ? null : CardKind.newWord;
    word ??= await repository.getReviewWord(now);
    actualKind ??= word == null ? null : CardKind.review;

    _showWord(word, actualKind);
  }

  Future<void> showRecentReview() async {
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final excludedServerWordId = currentWord?.serverWordId;
    final now = DateTime.now().toUtc();
    _telemetry.track(TelemetryEvent.recentReviewSwipeRequested);
    VocabularyWord? word = await repository.getRecentReviewWord(now);
    CardKind? actualKind = word == null ? null : CardKind.review;
    word ??= await repository.getNewWordWithFallback(
      excludeServerWordId: excludedServerWordId,
      proficiencyLevel: proficiency.level,
      deviceId: _deviceId,
    );
    actualKind ??= word == null ? null : CardKind.newWord;

    _showWord(word, actualKind);
  }

  void _showWord(VocabularyWord? word, CardKind? actualKind) {
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
    _deviceId ??= await repository.getOrCreateDeviceId();
    final updatedProficiency = await repository.recordRating(
      word: word,
      rating: rating,
      now: DateTime.now().toUtc(),
      deviceId: _deviceId!,
    );
    if (updatedProficiency != null) {
      final previousLevel = proficiency.level;
      proficiency = updatedProficiency;
      if (updatedProficiency.levelChanged && updatedProficiency.level != previousLevel) {
        _levelChangeMessage = 'Level changed: ${updatedProficiency.previousLevel ?? previousLevel} -> ${updatedProficiency.level}';
      }
    }
    _telemetry.track(TelemetryEvent.studyRatingSubmitted, {
      'rating': rating.name,
      'word_id': word.serverWordId ?? word.localId,
    });
    await nextCard();
  }

  Future<void> register({
    required String identifier,
    required String password,
    String? displayName,
  }) async {
    statusMessage = null;
    userSession = await repository.registerUser(
      identifier: identifier,
      password: password,
      displayName: displayName,
    );
    notifyListeners();
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    statusMessage = null;
    userSession = await repository.signInUser(
      identifier: identifier,
      password: password,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await repository.signOutUser();
    userSession = null;
    notifyListeners();
  }
}
