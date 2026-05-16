import 'dart:async';
import 'dart:math';

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
  final Random _fitbRandom = Random.secure();

  VocabularyWord? currentWord;
  CardKind? currentCardKind;
  bool isLoading = false;
  bool isAuthInProgress = false;
  Timer? _inventoryTimer;
  bool _topUpInFlight = false;
  final Duration _inventoryTopUpInterval = const Duration(hours: 1);
  final Duration _cardSelectionWatchdog = const Duration(seconds: 8);
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
    await showNewWord();
    _refreshProficiencyInBackground(
      deviceId: _deviceId!,
      language: _activeLearningLanguage,
    );
    _triggerInventoryTopUp();
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
    await showNewWord();
    _startInventoryTimer();
    _refreshProficiencyInBackground(
      deviceId: _deviceId!,
      language: _activeLearningLanguage,
    );
    _triggerInventoryTopUp();
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
    await _showSelectedCard(mode: _CardSelectionMode.newFirst);
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
    final language = _activeLearningLanguage;
    try {
      _deviceId ??= await repository.getOrCreateDeviceId();
      await repository.recordRememberedGesture(
        word: word,
        now: DateTime.now().toUtc(),
        deviceId: _deviceId!,
        onProficiency: (updated) => _applyGestureProficiency(updated, language),
      );
      await _logger.info(
        category: AppLogCategory.session,
        event: 'session.gesture.bottom_to_top',
        message:
            'Marked current word as remembered with low relearn frequency.',
        context: {'word_id': word.serverWordId ?? word.localId},
      );
      _telemetry.track(TelemetryEvent.studyRatingSubmitted, {
        'rating': StudyRating.tooEasy.apiValue,
        'word_id': word.serverWordId ?? word.localId,
      });
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.gesture.bottom_to_top.failed',
        message: 'Remembered gesture update failed.',
        context: {'error': '$error'},
      );
      return;
    }
    await nextCard();
  }

  Future<void> onSwipeTopToBottom() async {
    final word = currentWord;
    if (word == null || isLoading) {
      return;
    }
    final language = _activeLearningLanguage;
    try {
      _deviceId ??= await repository.getOrCreateDeviceId();
      await repository.recordDifficultGesture(
        word: word,
        now: DateTime.now().toUtc(),
        deviceId: _deviceId!,
        onProficiency: (updated) => _applyGestureProficiency(updated, language),
      );
      await _logger.info(
        category: AppLogCategory.session,
        event: 'session.gesture.top_to_bottom',
        message: 'Marked current word as difficult for relearn group.',
        context: {'word_id': word.serverWordId ?? word.localId},
      );
      _telemetry.track(TelemetryEvent.studyRatingSubmitted, {
        'rating': StudyRating.tooHard.apiValue,
        'word_id': word.serverWordId ?? word.localId,
      });
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.gesture.top_to_bottom.failed',
        message: 'Difficult gesture update failed.',
        context: {'error': '$error'},
      );
      return;
    }
    await nextCard();
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
    var didShowWord = false;
    // Watchdog: under no circumstance should isLoading remain true beyond the
    // configured timeout — the gesture surface gates on it and a stuck flag
    // freezes the entire screen.
    final watchdog = Timer(_cardSelectionWatchdog, () {
      if (!isLoading) return;
      isLoading = false;
      statusMessage ??= emptyMessage;
      notifyListeners();
    });
    try {
      if (beforeSelect != null) {
        await beforeSelect();
      }

      final now = DateTime.now().toUtc();
      final preferredKind = mode == _CardSelectionMode.mixed
          ? _selectionWindow.preferredKind()
          : mode.preferredKind;
      _safeLog(_logger.info(
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
      ));

      final selected = preferredKind == CardKind.newWord
          ? await _selectNewThenReview(now, emptyMessage: emptyMessage)
          : await _selectReviewThenNew(now, emptyMessage: emptyMessage);

      final word = selected.word;
      final actualKind = selected.kind;
      if (word == null) {
        _safeLog(_logger.warning(
          category: AppLogCategory.session,
          event: 'session.card_selection.empty',
          message: 'No learning card was available after fallback attempts.',
          context: {
            'requested_mode': mode.name,
            'active_language': _activeLearningLanguage,
            'preferred_kind': _kindName(preferredKind),
            'attempted_sources': selected.attemptedSources,
          },
        ));
      } else {
        _safeLog(_logger.info(
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
        ));
      }

      if (word != null && actualKind == CardKind.newWord) {
        // For new-word cards, run the threshold check only after the local
        // state transition (newWord → learning) completes. This ensures the
        // unstudied count has been decremented before we decide to fetch.
        unawaited(repository
            .markWordAsLearning(word: word, now: DateTime.now().toUtc())
            .then((_) => _triggerInventoryTopUp())
            .catchError((Object error) {
          _safeLog(_logger.warning(
            category: AppLogCategory.session,
            event: 'session.card_selection.local_state_failed',
            message: 'Selected card could not be marked as learning.',
            context: {
              'word_id': word.serverWordId ?? word.localId,
              'error': '$error',
            },
          ));
          // Still trigger even if the state transition failed.
          _triggerInventoryTopUp();
        }));
      } else {
        // Review cards and empty results: trigger immediately.
        _triggerInventoryTopUp();
      }

      _showWord(
        word,
        actualKind,
        emptyMessage: selected.message ?? emptyMessage,
      );
      didShowWord = true;
    } catch (error) {
      _safeLog(_logger.warning(
        category: AppLogCategory.session,
        event: 'session.card_selection.failed',
        message: 'Learning card selection failed.',
        context: {
          'requested_mode': mode.name,
          'active_language': _activeLearningLanguage,
          'error': '$error',
        },
      ));
    } finally {
      watchdog.cancel();
      // _showWord already toggled isLoading=false on success. On any other
      // path (early throw, log failure, watchdog already fired) ensure the UI
      // gets unblocked so the next gesture can drive a new selection.
      if (!didShowWord && isLoading) {
        isLoading = false;
        statusMessage ??= emptyMessage;
        notifyListeners();
      }
    }
  }

  /// Fire-and-forget log call that swallows any failure so the controller's
  /// hot path is never broken by logger misbehaviour.
  void _safeLog(Future<void> future) {
    unawaited(future.catchError((_) {}));
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
      currentCardKind = null;
      statusMessage = emptyMessage;
    } else {
      currentWord = word;
      currentCardKind = actualKind;
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
      _applyUpdatedProficiency(updatedProficiency);
    }
    _telemetry.track(TelemetryEvent.studyRatingSubmitted, {
      'rating': rating.name,
      'word_id': word.serverWordId ?? word.localId,
    });
    await nextCard();
  }

  void _applyGestureProficiency(
    ProficiencyState updatedProficiency,
    String gestureLanguage,
  ) {
    if (_activeLearningLanguage != gestureLanguage) {
      return;
    }
    _applyUpdatedProficiency(updatedProficiency, notify: true);
  }

  void _applyUpdatedProficiency(
    ProficiencyState updatedProficiency, {
    bool notify = false,
  }) {
    final previousLevel = proficiency.level;
    proficiency = updatedProficiency;
    if (updatedProficiency.levelChanged &&
        updatedProficiency.level != previousLevel) {
      _levelChangeMessage =
          'Level changed: ${updatedProficiency.previousLevel ?? previousLevel} -> ${updatedProficiency.level}';
      _safeLog(_logger.info(
        category: AppLogCategory.session,
        event: 'session.proficiency.changed',
        message: 'Proficiency level changed after rating submission.',
        context: {
          'previous_level': updatedProficiency.previousLevel ?? previousLevel,
          'new_level': updatedProficiency.level,
        },
      ));
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _refreshProficiencyInBackground({
    required String deviceId,
    required String language,
  }) {
    unawaited(() async {
      try {
        final updated = await repository.fetchProficiency(
          deviceId: deviceId,
          language: language,
        );
        if (_activeLearningLanguage != language) {
          return;
        }
        proficiency = updated;
        notifyListeners();
      } catch (error) {
        await _logger.warning(
          category: AppLogCategory.session,
          event: 'session.proficiency.fallback',
          message: 'Falling back to initial proficiency after fetch failure.',
          context: {
            'error': '$error',
            'language': language,
          },
        );
      }
    }());
  }

  void _startInventoryTimer() {
    _inventoryTimer?.cancel();
    _inventoryTimer = Timer.periodic(_inventoryTopUpInterval, (_) {
      _runInventoryTopUp();
    });
  }

  void _triggerInventoryTopUp() {
    unawaited(_runInventoryTopUp());
  }

  Future<void> _runInventoryTopUp() async {
    if (_topUpInFlight) return;
    _topUpInFlight = true;
    try {
      await repository.topUpInventoryIfNeeded();
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.session,
        event: 'session.inventory_top_up.failed',
        message: 'Background inventory top-up failed.',
        context: {'error': '$error'},
      );
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
      final backendReason = error.backendReason;
      if (action == AuthAction.register &&
          (error.statusCode == 409 || backendError == 'user_exists')) {
        return 'An account already exists for this email.';
      }
      if (action == AuthAction.signIn && backendReason == 'user_not_found') {
        return 'No account found. Please register.';
      }
      if (action == AuthAction.signIn &&
          (error.statusCode == 401 || backendError == 'invalid_credentials')) {
        return 'Email or password is incorrect.';
      }
      if (error.statusCode == 429 || backendError == 'too_many_requests') {
        return 'Too many attempts. Please wait a moment and try again.';
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

  /// Returns true when [word] meets all FITB eligibility conditions:
  /// - Review card (or a cached review/mastered word without `cardType`)
  /// - Non-empty example with at least 8 words
  /// - Term appears in the example (case-insensitive)
  /// - entry_type is word, phrase, or idiom
  /// - For phrase/idiom: blank_word is non-null and non-empty
  bool canFitb(VocabularyWord word, {CardKind? cardKind}) {
    final isReviewCard = cardKind == CardKind.review ||
        (cardKind == null &&
            (word.cardType == LearningCardType.review ||
                (word.cardType == null &&
                    (word.status == WordStatus.review ||
                        word.status == WordStatus.mastered))));
    if (!isReviewCard) return false;
    if (word.example.isEmpty) return false;
    if (word.example.split(' ').length < 8) return false;
    if (!word.example.toLowerCase().contains(word.term.toLowerCase())) {
      return false;
    }
    if (!const ['word', 'phrase', 'idiom'].contains(word.entryType)) {
      return false;
    }
    if (word.entryType != 'word') {
      final bw = word.blankWord;
      if (bw == null || bw.isEmpty) return false;
    }
    return true;
  }

  /// Returns true when [word] is eligible for FITB and random chance selects
  /// FITB mode. The 0.59 threshold gives ~50% FITB share of total session
  /// cards (accounting for the 85% review-card ratio).
  bool shouldShowFitb(VocabularyWord word, {CardKind? cardKind}) {
    final eligible = canFitb(word, cardKind: cardKind);
    final roll = eligible ? _fitbRandom.nextDouble() : null;
    final showFitb = eligible && roll! < 0.59;
    _safeLog(
      _logger.info(
        category: AppLogCategory.session,
        event: 'session.fitb.decision',
        message: 'Evaluated FITB eligibility for current card.',
        context: {
          'word_id': word.serverWordId ?? word.localId,
          'card_kind': cardKind?.name,
          'eligible': eligible,
          'roll': roll,
          'show_fitb': showFitb,
        },
      ),
    );
    return showFitb;
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
