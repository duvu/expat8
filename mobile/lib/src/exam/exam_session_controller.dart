import 'package:flutter/foundation.dart';

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
  ExamSessionController({
    required BackendApiClient apiClient,
    required LocalDatabase database,
  })  : _apiClient = apiClient,
        _database = database;

  final BackendApiClient _apiClient;
  final LocalDatabase _database;

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
      return _answers.firstWhere(
          (a) => a.questionIndex == _currentQuestionIndex);
    } catch (_) {
      return null;
    }
  }

  int get totalQuestions => _session?.questionCount ?? 0;
  bool get isLastQuestion =>
      _session != null &&
      _currentQuestionIndex == _session!.questions.length - 1;

  /// Fetches topics the user has studied words in for [language].
  Future<List<String>> fetchTopics({
    required UserSession userSession,
    String language = 'en',
  }) async {
    try {
      return await _apiClient.fetchExamTopics(
          sessionToken: userSession.sessionToken, language: language);
    } catch (_) {
      return [];
    }
  }

  /// Starts a new exam session for [topic] + [language].
  ///
  /// Sets [state] to [ExamState.loading] then [ExamState.active] on success,
  /// or leaves it in [ExamState.idle] and sets [errorMessage] on failure.
  Future<void> startSession({
    required UserSession userSession,
    required String topic,
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
      final response = await _apiClient.startExamSession(
        sessionToken: userSession.sessionToken,
        topic: topic,
        language: language,
      );
      _session = response;
      _state = ExamState.active;
    } on BackendApiException catch (e) {
      if (e.backendError == 'INSUFFICIENT_WORDS') {
        errorMessage = 'Not enough studied words for this topic. '
            'Keep learning and try again!';
      } else {
        errorMessage = 'Failed to start exam. Please try again.';
      }
      _state = ExamState.idle;
    } catch (_) {
      errorMessage = 'Failed to start exam. Please try again.';
      _state = ExamState.idle;
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

  /// Submits all answers to the backend and scores the session.
  ///
  /// Transitions to [ExamState.results] on success. Persists the attempt
  /// locally regardless of pass/fail.
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

    try {
      final response = await _apiClient.submitExamSession(
        sessionToken: userSession.sessionToken,
        sessionId: s.sessionId,
        answers: answerList,
      );
      _result = response;

      // Persist attempt locally for offline history.
      _database.saveExamAttempt(ExamAttemptEntity(
        attemptId: response.attemptId,
        sessionId: response.sessionId,
        topic: response.topic,
        language: response.language,
        difficultyLevel: response.difficultyLevel,
        totalQuestions: response.totalQuestions,
        correctCount: response.correctCount,
        scorePct: response.scorePct,
        passed: response.passed ? 1 : 0,
        createdAtMs: DateTime.tryParse(response.createdAt)
                ?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        certificateId: response.certificateId,
      ));

      _state = ExamState.results;
    } on BackendApiException catch (e) {
      errorMessage = e.backendError == 'SESSION_EXPIRED'
          ? 'Exam session expired. Please start a new exam.'
          : 'Failed to submit exam. Please try again.';
      _state = ExamState.active;
    } catch (_) {
      errorMessage = 'Failed to submit exam. Please try again.';
      _state = ExamState.active;
    }
    notifyListeners();
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
