import '../quiz/quiz_skills.dart';
import 'math_problem.dart';

/// Shared across all math games: missed facts and per-grade stats.
class MathSkillTracker extends SkillTracker<MathProblem> {
  MathSkillTracker(super.storage)
      : super(storageKey: 'games.math.skills.v1', decode: MathProblem.fromJson);
}
