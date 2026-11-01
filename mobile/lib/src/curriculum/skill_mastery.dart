/// One recorded answer to a skill-tagged question.
class SkillAnswer {
  const SkillAnswer({
    required this.skillId,
    required this.correct,
    required this.elapsedMs,
    required this.answeredAtMs,
    this.source = 'game',
  });

  final String skillId;
  final bool correct;
  final int elapsedMs;
  final int answeredAtMs;

  /// Where the answer came from (a game id, `party`, `placement`).
  final String source;
}

/// How well a learner knows a skill.
enum SkillStage { unseen, learning, familiar, mastered }

/// Derives a skill's stage by replaying its answers, so the same answers
/// always give the same stage whatever order they arrived in.
abstract final class SkillMastery {
  /// Answers that count toward "mastered": all correct and mostly fluent.
  static const masteredWindow = 5;
  static const masteredFluent = 4;

  /// Answers looked at for "familiar".
  static const recentWindow = 8;
  static const familiarMinAnswers = 3;
  static const familiarAccuracy = 0.7;

  /// [answers] belong to one skill of one owner; [targetSeconds] is the
  /// level's fluency target (a faster correct answer is fluent).
  static SkillStage fromAnswers(
    Iterable<SkillAnswer> answers, {
    required int targetSeconds,
  }) {
    final ordered = answers.toList()
      ..sort((a, b) {
        final byTime = a.answeredAtMs.compareTo(b.answeredAtMs);
        if (byTime != 0) return byTime;
        if (a.correct != b.correct) return a.correct ? 1 : -1;
        return a.elapsedMs.compareTo(b.elapsedMs);
      });
    if (ordered.isEmpty) return SkillStage.unseen;

    final targetMs = targetSeconds * 1000;
    final last = ordered.length > masteredWindow
        ? ordered.sublist(ordered.length - masteredWindow)
        : ordered;
    if (last.length == masteredWindow &&
        last.every((a) => a.correct) &&
        last.where((a) => a.elapsedMs <= targetMs).length >= masteredFluent) {
      return SkillStage.mastered;
    }

    final recent = ordered.length > recentWindow
        ? ordered.sublist(ordered.length - recentWindow)
        : ordered;
    final accuracy = recent.where((a) => a.correct).length / recent.length;
    if (ordered.length >= familiarMinAnswers && accuracy >= familiarAccuracy) {
      return SkillStage.familiar;
    }
    return SkillStage.learning;
  }
}
