/// A single question inside an exam session response.
class ExamQuestion {
  const ExamQuestion({
    required this.questionId,
    required this.ordinal,
    required this.promptWord,
    required this.choices,
    this.questionType = 'meaning_choice',
    this.sentence,
    this.highlight,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      questionId: json['question_id'] as String? ?? '',
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
      promptWord: json['prompt_word'] as String? ?? '',
      choices: ((json['choices'] as List<dynamic>?) ?? [])
          .whereType<String>()
          .toList(),
      questionType: json['question_type'] as String? ?? 'meaning_choice',
      sentence: json['sentence'] as String?,
      highlight: json['highlight'] as String?,
    );
  }

  final String questionId;
  final int ordinal;
  final String promptWord;
  final List<String> choices;

  /// `'meaning_choice'` or `'sentence_context'`.
  final String questionType;

  /// The example sentence for `sentence_context` questions. Null for `meaning_choice`.
  final String? sentence;

  /// The term to emphasize in [sentence] for `sentence_context` questions. Null for `meaning_choice`.
  final String? highlight;
}

/// Full exam session returned by `POST /v1/exam/start`.
class ExamSessionResponse {
  const ExamSessionResponse({
    required this.sessionId,
    required this.topic,
    required this.language,
    required this.questionCount,
    required this.expiresAt,
    required this.questions,
  });

  factory ExamSessionResponse.fromJson(Map<String, dynamic> json) {
    return ExamSessionResponse(
      sessionId: json['session_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] as String? ?? '',
      questions: ((json['questions'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ExamQuestion.fromJson)
          .toList(),
    );
  }

  final String sessionId;
  final String topic;
  final String language;
  final int questionCount;
  final String expiresAt;
  final List<ExamQuestion> questions;
}

/// Result returned by `POST /v1/exam/submit`.
class ExamSubmitResponse {
  const ExamSubmitResponse({
    required this.attemptId,
    required this.sessionId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePct,
    required this.passed,
    this.certificateId,
    required this.createdAt,
  });

  factory ExamSubmitResponse.fromJson(Map<String, dynamic> json) {
    return ExamSubmitResponse(
      attemptId: json['attempt_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      difficultyLevel: json['difficulty_level'] as String?,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      passed: json['passed'] == true,
      certificateId: json['certificate_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final String attemptId;
  final String sessionId;
  final String topic;
  final String language;
  final String? difficultyLevel;
  final int totalQuestions;
  final int correctCount;
  final double scorePct;
  final bool passed;
  final String? certificateId;
  final String createdAt;
}

/// A single item in the exam results list.
class ExamResultItem {
  const ExamResultItem({
    required this.attemptId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.scorePct,
    required this.passed,
    required this.createdAt,
    this.certificateId,
  });

  factory ExamResultItem.fromJson(Map<String, dynamic> json) {
    return ExamResultItem(
      attemptId: json['attempt_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      difficultyLevel: json['difficulty_level'] as String?,
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      passed: json['passed'] == true,
      createdAt: json['created_at'] as String? ?? '',
      certificateId: json['certificate_id'] as String?,
    );
  }

  final String attemptId;
  final String topic;
  final String language;
  final String? difficultyLevel;
  final double scorePct;
  final bool passed;
  final String createdAt;
  final String? certificateId;
}

/// Paginated exam results returned by `GET /v1/exam/results`.
class ExamResultsPage {
  const ExamResultsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory ExamResultsPage.fromJson(Map<String, dynamic> json) {
    return ExamResultsPage(
      items: ((json['items'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ExamResultItem.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );
  }

  final List<ExamResultItem> items;
  final int total;
  final int page;
  final int limit;
}

/// Public certificate returned by `GET /v1/exam/certificate/:id`.
class ExamCertificate {
  const ExamCertificate({
    required this.certificateId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.scorePct,
    required this.issuedAt,
    required this.disclaimer,
  });

  factory ExamCertificate.fromJson(Map<String, dynamic> json) {
    return ExamCertificate(
      certificateId: json['certificate_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      difficultyLevel: json['difficulty_level'] as String?,
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      issuedAt: json['issued_at'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  final String certificateId;
  final String topic;
  final String language;
  final String? difficultyLevel;
  final double scorePct;
  final String issuedAt;
  final String disclaimer;
}
