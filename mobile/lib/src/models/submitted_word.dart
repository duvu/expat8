import 'vocabulary_word.dart';

enum SubmittedWordStatus { queuedSync, queued, processing, ready, failed }

enum SubmittedWordResolutionType { existingWord, generatedWord }

class SubmittedWord {
  const SubmittedWord({
    required this.localSubmissionId,
    this.serverSubmissionId,
    required this.submittedTerm,
    required this.targetLanguage,
    required this.status,
    this.failureReason,
    this.resolutionType,
    this.resolvedWord,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory SubmittedWord.fromJson(
    Map<String, dynamic> json, {
    required String localSubmissionId,
  }) {
    return SubmittedWord(
      localSubmissionId: localSubmissionId,
      serverSubmissionId: json['id'] as String?,
      submittedTerm: json['submitted_term'] as String,
      targetLanguage: json['target_language'] as String,
      status: _submittedWordStatusFromJson(json['status'] as String?),
      failureReason: json['failure_reason'] as String?,
      resolutionType: _submittedWordResolutionTypeFromJson(
        json['resolution_type'] as String?,
      ),
      resolvedWord: json['resolved_word'] is Map<String, dynamic>
          ? VocabularyWord.fromJson(json['resolved_word'] as Map<String, dynamic>)
          : null,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.tryParse(json['resolved_at'] as String)?.toUtc(),
    );
  }

  final String localSubmissionId;
  final String? serverSubmissionId;
  final String submittedTerm;
  final String targetLanguage;
  final SubmittedWordStatus status;
  final String? failureReason;
  final SubmittedWordResolutionType? resolutionType;
  final VocabularyWord? resolvedWord;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  bool get isTerminal =>
      status == SubmittedWordStatus.ready || status == SubmittedWordStatus.failed;

  SubmittedWord copyWith({
    String? localSubmissionId,
    String? serverSubmissionId,
    String? submittedTerm,
    String? targetLanguage,
    SubmittedWordStatus? status,
    String? failureReason,
    SubmittedWordResolutionType? resolutionType,
    VocabularyWord? resolvedWord,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    bool clearFailureReason = false,
    bool clearResolutionType = false,
    bool clearResolvedWord = false,
    bool clearResolvedAt = false,
  }) {
    return SubmittedWord(
      localSubmissionId: localSubmissionId ?? this.localSubmissionId,
      serverSubmissionId: serverSubmissionId ?? this.serverSubmissionId,
      submittedTerm: submittedTerm ?? this.submittedTerm,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      status: status ?? this.status,
      failureReason:
          clearFailureReason ? null : failureReason ?? this.failureReason,
      resolutionType: clearResolutionType
          ? null
          : resolutionType ?? this.resolutionType,
      resolvedWord:
          clearResolvedWord ? null : resolvedWord ?? this.resolvedWord,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: clearResolvedAt ? null : resolvedAt ?? this.resolvedAt,
    );
  }
}

SubmittedWordStatus _submittedWordStatusFromJson(String? raw) {
  return switch (raw) {
    'ready' => SubmittedWordStatus.ready,
    'failed' => SubmittedWordStatus.failed,
    'queued' => SubmittedWordStatus.queued,
    'processing' => SubmittedWordStatus.processing,
    _ => SubmittedWordStatus.queuedSync,
  };
}

SubmittedWordResolutionType? _submittedWordResolutionTypeFromJson(String? raw) {
  return switch (raw) {
    'existing_word' => SubmittedWordResolutionType.existingWord,
    'generated_word' => SubmittedWordResolutionType.generatedWord,
    _ => null,
  };
}
