import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/backend_api_client.dart';
import '../config.dart';
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
    AppConfig? config,
  })  : _selectionWindow = selectionWindow ?? CardSelectionWindow(),
        _telemetry = telemetry ?? DebugTelemetrySink(),
        _logger = logger ?? const NoopLogger(),
        _config = config ?? AppConfig.fromEnvironment() {
    _activeLearningLanguage = _config.defaultLearningLanguage;
  }

  final WordRepository repository;
  final CardSelectionWindow _selectionWindow;
  final TelemetrySink _telemetry;
  final Logger _logger;
  final AppConfig _config;
  late String _activeLearningLanguage;

  VocabularyWord? currentWord;
  bool isLoading = false;
  bool isAuthInProgress = false;
  Timer? _inventoryTimer;
  bool _topUpInFlight = false;
  final Duration _inventoryTopUpInterval = const Duration(hours: 1);
  String? statusMessage;
  String? authSuccessMessage;
  String? authErrorMessage;
  ProficiencyState proficiency = ProficiencyState.initial();
  UserSession? userSession;
  String? _deviceId;
  String? _levelChangeMessage;
  String? _userFeedbackMessage;

  String get activeLearningLanguage => _activeLearningLanguage;

  List<String> get supportedLearningLanguages =>
      _config.supportedLearningLanguages;

  Future<void> setActiveLearningLanguage(String language) async {
    if (!_config.supportedLearningLanguages.contains(language)) {
      return;
    }
    if (_activeLearningLanguage == language) {
      return;
    }
    _activeLearningLanguage = language;
    repository.setActiveLanguage(language);
    notifyListeners();
    _deviceId ??= await repository.getOrCreateDeviceId();
    try {
      proficiency = await repository.fetchProficiency(
          deviceId: _deviceId!, language: _activeLearningLanguage);
    } catch (_) {
      proficiency = ProficiencyState.initial();
    }
    await repository.topUpInventoryIfNeeded();
    await showNewWord();
  }

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
      proficiency = await repository.fetchProficiency(
          deviceId: _deviceId!, language: _activeLearningLanguage);
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.proficiency.fallback',
        message: 'Falling back to initial proficiency after fetch failure.',
        context: {
          'error': '$error',
        },
      );
      proficiency = ProficiencyState.initial();
    }
    await showNewWord();
    _startInventoryTimer();
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
    await _showSelectedCard(mode: _CardSelectionMode.mixed);
  }

  Future<void> onSwipeRightToLeft() async {
    _telemetry.track(TelemetryEvent.newWordSwipeRequested);
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.gesture.right_to_left',
      message: 'Swipe right-to-left received.',
    );
    await _showSelectedCard(mode: _CardSelectionMode.mixed);
  }

  Future<void> onSwipeLeftToRight() async {
    _telemetry.track(TelemetryEvent.recentReviewSwipeRequested);
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.gesture.left_to_right',
      message: 'Swipe left-to-right received.',
    );
    await _showSelectedCard(mode: _CardSelectionMode.reviewFirst);
  }

  Future<void> onSwipeBottomToTop() async {
    final word = currentWord;
    if (word == null || isLoading) {
      return;
    }
    try {
      _deviceId ??= await repository.getOrCreateDeviceId();
      await repository.markRememberedLowFrequency(
        word: word,
        now: DateTime.now().toUtc(),
        deviceId: _deviceId!,
      );
      await _logger.info(
        category: AppLogCategory.session,
        event: 'session.gesture.bottom_to_top',
        message:
            'Marked current word as remembered with low relearn frequency.',
        context: {'word_id': word.serverWordId ?? word.localId},
      );
      await nextCard();
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.gesture.bottom_to_top.failed',
        message: 'Remembered gesture update failed.',
        context: {'error': '$error'},
      );
    }
  }

  Future<void> onSwipeTopToBottom() async {
    final word = currentWord;
    if (word == null || isLoading) {
      return;
    }
    try {
      _deviceId ??= await repository.getOrCreateDeviceId();
      await repository.markAsDifficultForRelearn(
        word: word,
        now: DateTime.now().toUtc(),
        deviceId: _deviceId!,
      );
      await _logger.info(
        category: AppLogCategory.session,
        event: 'session.gesture.top_to_bottom',
        message: 'Marked current word as difficult for relearn group.',
        context: {'word_id': word.serverWordId ?? word.localId},
      );
      await nextCard();
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.gesture.top_to_bottom.failed',
        message: 'Difficult gesture update failed.',
        context: {'error': '$error'},
      );
    }
  }

  Future<void> showNewWord() async {
    await _showSelectedCard(
      mode: _CardSelectionMode.newFirst,
      beforeSelect: () async {
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
      },
      emptyMessage:
          'No learning card is available. Check connection and try again.',
    );
  }

  Future<void> showRecentReview() async {
    await _showSelectedCard(
      mode: _CardSelectionMode.reviewFirst,
      beforeSelect: () async {
        _telemetry.track(TelemetryEvent.recentReviewSwipeRequested);
        await _logger.info(
          category: AppLogCategory.session,
          event: 'session.review.requested',
          message: 'User requested a recent review card.',
        );
      },
      emptyMessage: 'No review or new card is available. Try again later.',
    );
  }

  Future<void> _showSelectedCard({
    required _CardSelectionMode mode,
    Future<void> Function()? beforeSelect,
    String emptyMessage =
        'No learning card is available. Check connection and try again.',
  }) async {
    if (isLoading) {
      return;
    }
    isLoading = true;
    statusMessage = null;
    notifyListeners();

    if (beforeSelect != null) {
      await beforeSelect();
    }

    final now = DateTime.now().toUtc();
    final preferredKind = mode == _CardSelectionMode.mixed
        ? _selectionWindow.preferredKind()
        : mode.preferredKind;
    await _logger.info(
      category: AppLogCategory.session,
      event: 'session.card_selection.start',
      message: 'Started learning card selection.',
      context: {
        'requested_mode': mode.name,
        'active_language': _activeLearningLanguage,
        'preferred_kind': _kindName(preferredKind),
        'window_size': _selectionWindow.windowSize,
        'target_new_cards': _selectionWindow.targetNewCards,
        'history_count': _selectionWindow.history.length,
        'new_count': _selectionWindow.newCount,
        'review_count': _selectionWindow.reviewCount,
      },
    );

    final selected = preferredKind == CardKind.newWord
        ? await _selectNewThenReview(now, emptyMessage: emptyMessage)
        : await _selectReviewThenNew(now, emptyMessage: emptyMessage);

    final word = selected.word;
    final actualKind = selected.kind;
    if (word == null) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.card_selection.empty',
        message: 'No learning card was available after fallback attempts.',
        context: {
          'requested_mode': mode.name,
          'active_language': _activeLearningLanguage,
          'preferred_kind': _kindName(preferredKind),
          'attempted_sources': selected.attemptedSources,
        },
      );
    } else {
      await _logger.info(
        category: AppLogCategory.session,
        event: 'session.card_selection.selected',
        message: 'Selected learning card.',
        context: {
          'requested_mode': mode.name,
          'active_language': _activeLearningLanguage,
          'preferred_kind': _kindName(preferredKind),
          'actual_kind': _kindName(actualKind!),
          'source': _sourceName(selected.source),
          'word_id': word.serverWordId ?? word.localId,
        },
      );
    }

    _showWord(
      word,
      actualKind,
      emptyMessage: selected.message ?? emptyMessage,
    );
    if (word != null && actualKind == CardKind.newWord) {
      unawaited(
        repository.markWordAsLearning(
          word: word,
          now: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<_CardSelectionResult> _selectNewThenReview(
    DateTime now, {
    required String emptyMessage,
  }) async {
    final result = await repository.getNewWordWithFallbackResult(
      language: _activeLearningLanguage,
    );
    _trackNewWordLookup(result);
    if (result.word != null) {
      final kind = _kindForSource(result.source);
      if (kind == CardKind.review) {
        await _logSelectionFallback(
            from: CardKind.newWord, to: CardKind.review);
      }
      return _CardSelectionResult(
        word: result.word,
        kind: kind,
        source: result.source,
        attemptedSources: const ['new', 'review'],
        message: result.message,
      );
    }

    return _CardSelectionResult(
      word: null,
      kind: null,
      source: WordLookupSource.none,
      attemptedSources: const ['new', 'review'],
      message: result.message ?? emptyMessage,
    );
  }

  Future<_CardSelectionResult> _selectReviewThenNew(
    DateTime now, {
    required String emptyMessage,
  }) async {
    final reviewResult = await repository.getReviewFallbackResult(
      now,
      language: _activeLearningLanguage,
    );
    _trackReviewLookup(reviewResult);
    if (reviewResult.word != null) {
      return _CardSelectionResult(
        word: reviewResult.word,
        kind: CardKind.review,
        source: reviewResult.source,
        attemptedSources: const ['review'],
        message: reviewResult.message,
      );
    }

    await _logSelectionFallback(from: CardKind.review, to: CardKind.newWord);
    final newWordResult = await repository.getNewWordWithFallbackResult(
      language: _activeLearningLanguage,
    );
    _trackNewWordLookup(newWordResult);
    if (newWordResult.word != null) {
      return _CardSelectionResult(
        word: newWordResult.word,
        kind: _kindForSource(newWordResult.source),
        source: newWordResult.source,
        attemptedSources: const ['review', 'new'],
        message: newWordResult.message,
      );
    }

    return _CardSelectionResult(
      word: null,
      kind: null,
      source: WordLookupSource.none,
      attemptedSources: const ['review', 'new'],
      message: newWordResult.message ?? reviewResult.message ?? emptyMessage,
    );
  }

  Future<void> _logSelectionFallback({
    required CardKind from,
    required CardKind to,
  }) {
    return _logger.info(
      category: AppLogCategory.session,
      event: 'session.card_selection.fallback',
      message: 'Learning card selection fell back to another card kind.',
      context: {
        'active_language': _activeLearningLanguage,
        'from': _kindName(from),
        'to': _kindName(to),
      },
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

  void _startInventoryTimer() {
    _inventoryTimer?.cancel();
    _inventoryTimer = Timer.periodic(_inventoryTopUpInterval, (_) {
      _runInventoryTopUp();
    });
  }

  Future<void> _runInventoryTopUp() async {
    if (_topUpInFlight) return;
    _topUpInFlight = true;
    try {
      await repository.topUpInventoryIfNeeded();
    } finally {
      _topUpInFlight = false;
    }
  }

  @override
  void dispose() {
    _inventoryTimer?.cancel();
    _inventoryTimer = null;
    super.dispose();
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
      case WordLookupSource.localFallback:
      case WordLookupSource.randomFallback:
        _telemetry.track(TelemetryEvent.newWordLocalFallback);
        return;
      case WordLookupSource.none:
        _telemetry.track(TelemetryEvent.newWordFallbackMiss);
        return;
      case WordLookupSource.recentReview:
      case WordLookupSource.dueReview:
      case WordLookupSource.difficultRelearn:
        return;
    }
  }

  void _trackReviewLookup(WordLookupResult result) {
    switch (result.source) {
      case WordLookupSource.recentReview:
      case WordLookupSource.dueReview:
      case WordLookupSource.difficultRelearn:
        _telemetry.track(TelemetryEvent.recentReviewHit);
        return;
      case WordLookupSource.none:
        _telemetry.track(TelemetryEvent.recentReviewMiss);
        return;
      case WordLookupSource.localFallback:
      case WordLookupSource.randomFallback:
        return;
    }
  }

  CardKind _kindForSource(WordLookupSource source) {
    return switch (source) {
      WordLookupSource.localFallback => CardKind.newWord,
      WordLookupSource.randomFallback ||
      WordLookupSource.recentReview ||
      WordLookupSource.dueReview ||
      WordLookupSource.difficultRelearn =>
        CardKind.review,
      WordLookupSource.none => CardKind.review,
    };
  }

  String _kindName(CardKind kind) {
    return switch (kind) {
      CardKind.newWord => 'new',
      CardKind.review => 'review',
    };
  }

  String _sourceName(WordLookupSource source) {
    return switch (source) {
      WordLookupSource.localFallback => 'new',
      WordLookupSource.randomFallback => 'random_fallback',
      WordLookupSource.recentReview => 'recent_review',
      WordLookupSource.dueReview => 'due_review',
      WordLookupSource.difficultRelearn => 'difficult_relearn',
      WordLookupSource.none => 'none',
    };
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

enum _CardSelectionMode {
  mixed,
  newFirst,
  reviewFirst;

  CardKind get preferredKind {
    return switch (this) {
      _CardSelectionMode.mixed => CardKind.review,
      _CardSelectionMode.newFirst => CardKind.newWord,
      _CardSelectionMode.reviewFirst => CardKind.review,
    };
  }
}

class _CardSelectionResult {
  const _CardSelectionResult({
    required this.word,
    required this.kind,
    required this.source,
    required this.attemptedSources,
    this.message,
  });

  final VocabularyWord? word;
  final CardKind? kind;
  final WordLookupSource source;
  final List<String> attemptedSources;
  final String? message;
}
