import 'dart:math';

import '../../curriculum/skill_answer_sink.dart';
import '../../curriculum/skill_mastery.dart';
import 'quiz_core.dart';
import 'quiz_skills.dart';

class QuizAnswer<T extends QuizItem> {
  const QuizAnswer({
    required this.item,
    required this.correct,
    required this.elapsed,
    this.given,
  });

  final T item;
  final bool correct;
  final Duration elapsed;
  final String? given;
}

/// Scoring and bookkeeping shared by every quiz game. Each answer feeds the
/// adaptive source and the skill tracker, so all games train the same skills.
class QuizRoundLog<T extends QuizItem, L extends QuizLevel> {
  QuizRoundLog({
    required this.level,
    required this.generator,
    required this.skills,
    this.skillSink,
  });

  final L level;
  final QuizSource<T> generator;
  final SkillTracker<T> skills;

  /// Where answers to skill-tagged items are recorded; null records nothing
  /// (a party host does not record other players' answers).
  final SkillAnswerSink? skillSink;
  final List<QuizAnswer<T>> answers = [];
  int score = 0;
  int combo = 0;
  int bestCombo = 0;

  /// Records an answer and returns the points it earned. Points reward speed
  /// (up to double for an instant answer) and streaks, never luck.
  int submit(
    T item, {
    required bool correct,
    required Duration elapsed,
    String? given,
  }) {
    answers.add(QuizAnswer(
        item: item, correct: correct, elapsed: elapsed, given: given));
    generator.recordResult(correct: correct, elapsed: elapsed);
    skills.record(level, item, correct: correct, elapsed: elapsed);
    final skillId = item.skillId;
    if (skillId != null) {
      skillSink?.record(SkillAnswer(
        skillId: skillId,
        correct: correct,
        elapsedMs: elapsed.inMilliseconds,
        answeredAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    if (!correct) {
      combo = 0;
      return 0;
    }
    combo++;
    bestCombo = max(bestCombo, combo);
    final points = pointsFor(elapsed) + min<int>(combo - 1, 10);
    score += points;
    return points;
  }

  /// 10 points for a correct answer plus up to 10 for speed.
  int pointsFor(Duration elapsed) {
    final target = level.targetSeconds * Duration.millisecondsPerSecond;
    final speed = 1 - elapsed.inMilliseconds / (target * 2);
    return 10 + (10 * speed.clamp(0.0, 1.0)).round();
  }

  int get answered => answers.length;
  int get correctCount => answers.where((a) => a.correct).length;
  double get accuracy => answered == 0 ? 0 : correctCount / answered;

  /// Average seconds per correct answer.
  double get averageSeconds {
    final correct = answers.where((a) => a.correct).toList();
    if (correct.isEmpty) return 0;
    final ms = correct.fold<int>(0, (sum, a) => sum + a.elapsed.inMilliseconds);
    return ms / correct.length / Duration.millisecondsPerSecond;
  }

  /// Distinct items missed this round, for the review list.
  List<T> get missed {
    final seen = <String>{};
    return [
      for (final a in answers)
        if (!a.correct && seen.add(a.item.key)) a.item,
    ];
  }
}
