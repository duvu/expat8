import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../data/local_database.dart';
import '../data/local_database_entities.dart';
import '../models/user_session.dart';

/// Represents the lifecycle state of an exam session.
enum ExamState {
  /// No session active; topic/language picker is shown.
  idle,

  /// Fetching the question set from the backend.
  loading,

  /// Questions received; user is answering.
  active,

  /// Submitting answers to the backend.
  submitting,

  /// Session scored; results are shown.
  results,
}

/// Holds the user's per-question answer state during an active session.
class ExamAnswerState {
  const ExamAnswerState({
    required this.questionIndex,
    required this.selectedChoice,
    required this.isCorrect,
  });

  final int questionIndex;

  /// 0-based index into the question's `choices` list.
  final int selectedChoice;
  final bool isCorrect;
}

/// Manages the lifecycle of a single vocabulary exam session.
///
/// Does NOT touch [LearningSessionController] or any SRS state.
class ExamSessionController extends ChangeNotifier {
  static const String _backendUnavailableMessage =
      'Backend unavailable. Please try again.';

  ExamSessionController({
    required BackendApiClient apiClient,
    required LocalDatabase database,
  })  : _apiClient = apiClient,
        _database = database;

  final BackendApiClient _apiClient;
  final LocalDatabase _database;

  BackendApiClient get apiClient => _apiClient;

  ExamState _state = ExamState.idle;
  ExamState get state => _state;

  String? errorMessage;

  /// The session received from the backend after `startSession()`.
  ExamSessionResponse? _session;
  ExamSessionResponse? get session => _session;

  /// The result received from the backend after `submitSession()`.
  ExamSubmitResponse? _result;
  ExamSubmitResponse? get result => _result;

  /// Per-question answers accumulated during the session.
  final List<ExamAnswerState> _answers = [];
  List<ExamAnswerState> get answers => List.unmodifiable(_answers);

  /// Index of the question currently displayed.
  int _currentQuestionIndex = 0;
  int get currentQuestionIndex => _currentQuestionIndex;

  ExamQuestion? get currentQuestion {
    final s = _session;
    if (s == null || _currentQuestionIndex >= s.questions.length) return null;
    return s.questions[_currentQuestionIndex];
  }

  bool get hasAnsweredCurrent =>
      _answers.any((a) => a.questionIndex == _currentQuestionIndex);

  ExamAnswerState? get currentAnswer {
    try {
      return _answers
          .firstWhere((a) => a.questionIndex == _currentQuestionIndex);
    } catch (_) {
      return null;
    }
  }

  int get totalQuestions => _session?.questionCount ?? 0;
  bool get isLastQuestion =>
      _session != null &&
      _currentQuestionIndex == _session!.questions.length - 1;

  void _setBackendUnavailableError() {
    errorMessage = _backendUnavailableMessage;
    _state = ExamState.idle;
  }

  /// Starts a new exam session for [language].
  ///
  /// Sets [state] to [ExamState.loading] then [ExamState.active] on success,
  /// or leaves it in [ExamState.idle] and sets [errorMessage] on failure.
  Future<void> startSession({
    required UserSession userSession,
    String language = 'en',
  }) async {
    _state = ExamState.loading;
    errorMessage = null;
    _session = null;
    _result = null;
    _answers.clear();
    _currentQuestionIndex = 0;
    notifyListeners();

    try {
      final backendReady = await _apiClient.checkBackendReadiness();
      if (!backendReady) {
        _setBackendUnavailableError();
        notifyListeners();
        return;
      }

      final response = await _apiClient.startExamSession(
        sessionToken: userSession.sessionToken,
        language: language,
      );
      _session = response;
      _state = ExamState.active;
    } on BackendApiException catch (e) {
      if (e.backendError == 'INSUFFICIENT_WORDS') {
        errorMessage = 'Not enough studied words for this language. '
            'Keep learning and try again!';
      } else if (e.statusCode != null && e.statusCode! >= 500) {
        _setBackendUnavailableError();
      } else {
        errorMessage = 'Failed to start exam. Please try again.';
      }
      _state = ExamState.idle;
    } catch (_) {
      _setBackendUnavailableError();
    }
    notifyListeners();
  }

  /// Records the user's answer for the current question.
  ///
  /// [choiceIndex] is the 0-based index into the question's `choices` list.
  /// Does nothing if the current question has already been answered.
  void submitAnswer(int choiceIndex) {
    if (hasAnsweredCurrent) return;
    final q = currentQuestion;
    if (q == null) return;

    // Determine correctness by comparing with the correct index, which we
    // don't store client-side (backend only). We track the selected index and
    // let the backend score officially. For immediate UI feedback we mark all
    // answers as initially unknown — the results page uses server score.
    // However, to show per-question correct/incorrect highlights we need the
    // correct index. The backend intentionally withholds it. So we surface
    // feedback only on the results screen after submission.
    _answers.add(ExamAnswerState(
      questionIndex: _currentQuestionIndex,
      selectedChoice: choiceIndex,
      isCorrect: false, // finalised after server scoring
    ));
    notifyListeners();
  }

  /// Commits the current answer and advances or submits as needed.
  Future<void> submitAnswerAndAdvance({
    required UserSession userSession,
    required int choiceIndex,
  }) async {
    if (hasAnsweredCurrent || _state == ExamState.submitting) {
      return;
    }
    submitAnswer(choiceIndex);
    if (isLastQuestion) {
      await submitSession(userSession: userSession);
      return;
    }
    _currentQuestionIndex++;
    notifyListeners();
  }

  /// Advances to the next question, or transitions to [ExamState.submitting]
  /// and calls [submitSession] if all questions have been answered.
  ///
  /// No-ops if a submission is already in flight, preventing double-tap races.
  Future<void> advance({required UserSession userSession}) async {
    if (!hasAnsweredCurrent) return;
    if (_state == ExamState.submitting) return;
    if (!isLastQuestion) {
      _currentQuestionIndex++;
      notifyListeners();
    } else {
      await submitSession(userSession: userSession);
    }
  }

  /// Submits all answers: persists locally first, then syncs to backend in background.
  ///
  /// Transitions to [ExamState.results] immediately after local save so the
  /// user is never blocked by backend latency. The backend call runs in the
  /// background; when it completes, [result] is set and listeners are notified
  /// so the results screen can update reactively.
  Future<void> submitSession({required UserSession userSession}) async {
    final s = _session;
    if (s == null) return;

    _state = ExamState.submitting;
    errorMessage = null;
    notifyListeners();

    // Build answer array in ordinal order.
    final answerList = List<int>.filled(s.questions.length, 0);
    for (final a in _answers) {
      if (a.questionIndex < answerList.length) {
        answerList[a.questionIndex] = a.selectedChoice;
      }
    }

    // Step 1: Generate a stable client-side attempt ID for idempotency.
    final localAttemptId = const Uuid().v4();

    // Step 2: Persist the attempt locally with 'pending' sync status.
    // Score fields are left at 0 and will be updated once the backend responds.
    _database.saveExamAttempt(ExamAttemptEntity(
      attemptId: localAttemptId,
      sessionId: s.sessionId,
      topic: s.topic ?? 'language',
      language: s.language ?? 'en',
      difficultyLevel: null,
      totalQuestions: s.questionCount,
      correctCount: 0,
      scorePct: 0.0,
      passed: 0,
      createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      certificateId: null,
      syncStatus: 'pending',
    ));

    // Step 3: Enqueue for background sync (retry-safe).
    _database.enqueueExamResult(
      localAttemptId: localAttemptId,
      sessionId: s.sessionId,
      answers: answerList,
      language: s.language ?? 'en',
    );

    // Step 4: Transition to results immediately — user is not blocked.
    _state = ExamState.results;
    notifyListeners();

    // Step 5: Submit to backend in background; update local record on success.
    _submitToBackendInBackground(
      userSession: userSession,
      localAttemptId: localAttemptId,
      sessionId: s.sessionId,
      answers: answerList,
    );
  }

  /// Calls the backend submit endpoint and, on success, updates the local
  /// attempt record and notifies listeners so the results screen can render.
  ///
  /// Failures are silently swallowed — the queue entry will be retried by the
  /// background sync worker. The results screen's 20-second timeout handles
  /// the case where the backend never responds.
  Future<void> _submitToBackendInBackground({
    required UserSession userSession,
    required String localAttemptId,
    required String sessionId,
    required List<int> answers,
  }) async {
    try {
      final response = await _apiClient.submitExamSession(
        sessionToken: userSession.sessionToken,
        sessionId: sessionId,
        answers: answers,
        localAttemptId: localAttemptId,
      );
      _result = response;

      // Update the local record with the server-confirmed scores.
      _database.markExamAttemptSynced(
        localAttemptId: localAttemptId,
        serverAttemptId: response.attemptId,
        correctCount: response.correctCount,
        scorePct: response.scorePct,
        passed: response.passed,
        certificateId: response.certificateId,
      );

      notifyListeners();
    } catch (_) {
      // Backend sync failed; the queue entry will be retried in the background.
      // Do not surface an error here — the attempt is safely persisted locally.
    }
  }

  /// Resets the controller to [ExamState.idle] for a new exam attempt.
  void reset() {
    _state = ExamState.idle;
    _session = null;
    _result = null;
    _answers.clear();
    _currentQuestionIndex = 0;
    errorMessage = null;
    notifyListeners();
  }
}
