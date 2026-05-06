import 'package:flutter/foundation.dart';

import '../api/backend_api_client.dart';
import '../data/word_repository.dart';
import '../logging/logger.dart';
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
    Logger? logger,
  })  : _selectionWindow = selectionWindow ?? CardSelectionWindow(),
        _telemetry = telemetry ?? DebugTelemetrySink(),
        _logger = logger ?? const NoopLogger();

  final WordRepository repository;
  final CardSelectionWindow _selectionWindow;
  final TelemetrySink _telemetry;
  final Logger _logger;

  VocabularyWord? currentWord;
  bool isLoading = false;
  bool isAuthInProgress = false;
  String? statusMessage;
  String? authSuccessMessage;
  String? authErrorMessage;
  ProficiencyState proficiency = ProficiencyState.initial();
  UserSession? userSession;
  String? _deviceId;
  String? _levelChangeMessage;
  String? _userFeedbackMessage;

  String? takeLevelChangeMessage() {
    final message = _levelChangeMessage;
    _levelChangeMessage = null;
    return message;
  }

  String? takeUserFeedbackMessage() {
    final message = _userFeedbackMessage;
    _userFeedbackMessage = null;
    return message;
  }

  String? get userDisplayLabel {
    final session = userSession;
    if (session == null) {
      return null;
    }
    final displayName = session.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return session.identifier;
  }

  Future<void> loadInitial() async {
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.load_initial.start',
      message: 'Loading initial session state.',
    );
    _deviceId ??= await repository.getOrCreateDeviceId();
    userSession = await repository.loadUserSession();
    try {
      proficiency = await repository.fetchProficiency(deviceId: _deviceId!);
    } catch (_) {
      proficiency = ProficiencyState.initial();
    }
    await showNewWord();
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.load_initial.complete',
      message: 'Initial session state loaded.',
      context: {
        'has_user_session': userSession != null,
        'proficiency_level': proficiency.level,
      },
    );
  }

  Future<void> nextCard() async {
    await showNewWord();
  }

  Future<void> showNewWord() async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final now = DateTime.now().toUtc();
    VocabularyWord? word;
    CardKind? actualKind;

    _telemetry.track(TelemetryEvent.newWordRequested);
    _telemetry.track(TelemetryEvent.newWordSwipeRequested);
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.new_word.requested',
      message: 'User requested a new word card.',
      context: {
        'proficiency_level': proficiency.level,
      },
    );
    final result = await repository.getNewWordWithFallbackResult(
      deviceId: _deviceId,
    );
    word = result.word;
    _trackNewWordLookup(result);
    actualKind = word == null ? null : CardKind.newWord;
    word ??= await repository.getReviewWord(now);
    actualKind ??= word == null ? null : CardKind.review;

    _showWord(
      word,
      actualKind,
      emptyMessage: result.message ??
          'No learning card is available. Check connection and try again.',
    );
  }

  Future<void> showRecentReview() async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    final now = DateTime.now().toUtc();
    _telemetry.track(TelemetryEvent.recentReviewSwipeRequested);
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.review.requested',
      message: 'User requested a recent review card.',
    );
    final reviewResult = await repository.getRecentReviewWordResult(now);
    _trackReviewLookup(reviewResult);
    VocabularyWord? word = reviewResult.word;
    CardKind? actualKind = word == null ? null : CardKind.review;
    final newWordResult = word == null
        ? await repository.getNewWordWithFallbackResult(
            deviceId: _deviceId,
          )
        : null;
    if (newWordResult != null) {
      _trackNewWordLookup(newWordResult);
      word = newWordResult.word;
    }
    actualKind ??= word == null ? null : CardKind.newWord;

    _showWord(
      word,
      actualKind,
      emptyMessage: newWordResult?.message ??
          reviewResult.message ??
          'No review or new card is available. Try again later.',
    );
  }

  void _showWord(
    VocabularyWord? word,
    CardKind? actualKind, {
    required String emptyMessage,
  }) {
    if (word == null) {
      currentWord = null;
      statusMessage = emptyMessage;
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
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.rating.submitted',
      message: 'Submitting study rating for current card.',
      context: {
        'rating': rating.name,
        'word_id': word.serverWordId ?? word.localId,
      },
    );
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
      if (updatedProficiency.levelChanged &&
          updatedProficiency.level != previousLevel) {
        _levelChangeMessage =
            'Level changed: ${updatedProficiency.previousLevel ?? previousLevel} -> ${updatedProficiency.level}';
        await _logger.info(
          category: AppLogCategory.session,
          event: 'session.proficiency.changed',
          message: 'Proficiency level changed after rating submission.',
          context: {
            'previous_level': updatedProficiency.previousLevel ?? previousLevel,
            'new_level': updatedProficiency.level,
          },
        );
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
    if (isAuthInProgress) {
      return;
    }
    final previousSession = userSession;
    _beginAuthAction();
    try {
      final session = await repository.registerUser(
        identifier: identifier,
        password: password,
        displayName: displayName,
      );
      userSession = session;
      authSuccessMessage = 'Registered as ${_displayLabelFor(session)}.';
      _userFeedbackMessage = authSuccessMessage;
      _telemetry.track(TelemetryEvent.authRegisterSuccess, {
        'user_id': session.userId,
      });
    } catch (error) {
      userSession = previousSession;
      authErrorMessage = _authFailureMessage(AuthAction.register, error);
      _userFeedbackMessage = authErrorMessage;
      _telemetry.track(TelemetryEvent.authRegisterFailure, {
        'error': '$error',
      });
    } finally {
      _endAuthAction();
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    if (isAuthInProgress) {
      return;
    }
    final previousSession = userSession;
    _beginAuthAction();
    try {
      final session = await repository.signInUser(
        identifier: identifier,
        password: password,
      );
      userSession = session;
      authSuccessMessage = 'Signed in as ${_displayLabelFor(session)}.';
      _userFeedbackMessage = authSuccessMessage;
      _telemetry.track(TelemetryEvent.authSignInSuccess, {
        'user_id': session.userId,
      });
    } catch (error) {
      userSession = previousSession;
      authErrorMessage = _authFailureMessage(AuthAction.signIn, error);
      _userFeedbackMessage = authErrorMessage;
      _telemetry.track(TelemetryEvent.authSignInFailure, {
        'error': '$error',
      });
    } finally {
      _endAuthAction();
    }
  }

  Future<void> signOut() async {
    if (isAuthInProgress) {
      return;
    }
    _beginAuthAction();
    try {
      await repository.signOutUser();
      userSession = null;
      authSuccessMessage = 'Signed out.';
      _userFeedbackMessage = authSuccessMessage;
      _telemetry.track(TelemetryEvent.authSignOutSuccess);
    } catch (error) {
      userSession = await repository.loadUserSession();
      final clearedLocally = userSession == null;
      authErrorMessage = clearedLocally
          ? 'Signed out locally. Server sign-out could not be confirmed.'
          : _authFailureMessage(AuthAction.signOut, error);
      _userFeedbackMessage = authErrorMessage;
      _telemetry.track(TelemetryEvent.authSignOutFailure, {
        'error': '$error',
        'cleared_locally': clearedLocally,
      });
    } finally {
      _endAuthAction();
    }
  }

  void _beginAuthAction() {
    isAuthInProgress = true;
    statusMessage = null;
    authSuccessMessage = null;
    authErrorMessage = null;
    notifyListeners();
  }

  void _endAuthAction() {
    isAuthInProgress = false;
    notifyListeners();
  }

  void _trackNewWordLookup(WordLookupResult result) {
    switch (result.source) {
      case WordLookupSource.backend:
        _telemetry.track(TelemetryEvent.newWordBackendSuccess);
        return;
      case WordLookupSource.localFallback:
        _telemetry.track(TelemetryEvent.newWordLocalFallback);
        return;
      case WordLookupSource.none:
        _telemetry.track(TelemetryEvent.newWordFallbackMiss);
        return;
      case WordLookupSource.recentReview:
      case WordLookupSource.dueReview:
        return;
    }
  }

  void _trackReviewLookup(WordLookupResult result) {
    switch (result.source) {
      case WordLookupSource.recentReview:
      case WordLookupSource.dueReview:
        _telemetry.track(TelemetryEvent.recentReviewHit);
        return;
      case WordLookupSource.none:
        _telemetry.track(TelemetryEvent.recentReviewMiss);
        return;
      case WordLookupSource.backend:
      case WordLookupSource.localFallback:
        return;
    }
  }

  String _displayLabelFor(UserSession session) {
    final displayName = session.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return session.identifier;
  }

  String _authFailureMessage(AuthAction action, Object error) {
    _logger.warning(
      category: AppLogCategory.auth,
      event: 'auth.failure',
      message: '${action.failureLabel} failed.',
      context: {
        'error': '$error',
      },
    );
    if (error is BackendApiException) {
      final backendError = error.backendError;
      if (action == AuthAction.register &&
          (error.statusCode == 409 || backendError == 'user_exists')) {
        return 'An account already exists for this email.';
      }
      if (action == AuthAction.signIn &&
          (error.statusCode == 401 || backendError == 'invalid_credentials')) {
        return 'Email or password is incorrect.';
      }
      if (error.statusCode == 400 || backendError == 'bad_request') {
        return 'The request was rejected. Check the entered details and try again.';
      }
      if (error.statusCode != null) {
        return '${action.failureLabel} failed. Server returned ${error.statusCode}.';
      }
    }
    return '${action.failureLabel} failed. Check connection and try again.';
  }
}

enum AuthAction {
  register('Registration'),
  signIn('Sign-in'),
  signOut('Sign-out');

  const AuthAction(this.failureLabel);

  final String failureLabel;
}
