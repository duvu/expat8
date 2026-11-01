import 'package:expat8_language_app/src/curriculum/skill_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

const _target = 5;

SkillAnswer _a(int at, {bool correct = true, int ms = 2000}) => SkillAnswer(
    skillId: 'math.x', correct: correct, elapsedMs: ms, answeredAtMs: at);

SkillStage _stage(List<SkillAnswer> answers) =>
    SkillMastery.fromAnswers(answers, targetSeconds: _target);

void main() {
  test('no answers is unseen', () {
    expect(_stage([]), SkillStage.unseen);
  });

  test('one correct answer is learning, never mastered', () {
    expect(_stage([_a(1)]), SkillStage.learning);
  });

  test('a few mostly right answers are familiar', () {
    expect(_stage([_a(1), _a(2), _a(3, correct: false), _a(4), _a(5)]),
        SkillStage.familiar);
  });

  test('mostly wrong answers stay learning', () {
    expect(_stage([_a(1, correct: false), _a(2), _a(3, correct: false)]),
        SkillStage.learning);
  });

  test('a fluent run of correct answers is mastered', () {
    expect(_stage([for (var i = 1; i <= 5; i++) _a(i)]), SkillStage.mastered);
  });

  test('correct but slow answers are not mastered', () {
    expect(_stage([for (var i = 1; i <= 5; i++) _a(i, ms: 9000)]),
        SkillStage.familiar);
  });

  test('one slow answer among five fluent ones still counts', () {
    expect(_stage([for (var i = 1; i <= 4; i++) _a(i), _a(5, ms: 9000)]),
        SkillStage.mastered);
  });

  test('repeated recent misses demote a mastered skill', () {
    final answers = [
      for (var i = 1; i <= 5; i++) _a(i),
      _a(6, correct: false),
      _a(7, correct: false),
      _a(8, correct: false),
    ];
    expect(_stage(answers), SkillStage.learning);
  });

  test('old misses do not block mastery', () {
    final answers = [
      _a(1, correct: false),
      _a(2, correct: false),
      for (var i = 3; i <= 7; i++) _a(i),
    ];
    expect(_stage(answers), SkillStage.mastered);
  });

  test('arrival order does not change the stage', () {
    final answers = [
      for (var i = 1; i <= 5; i++) _a(i),
      _a(6, correct: false),
      _a(7),
    ];
    final shuffled = [...answers.reversed];
    expect(_stage(shuffled), _stage(answers));
    final rotated = [...answers.sublist(3), ...answers.sublist(0, 3)];
    expect(_stage(rotated), _stage(answers));
  });

  test('answers with the same time are ordered deterministically', () {
    final a = [_a(1, correct: false), _a(1), _a(1), _a(1), _a(1), _a(1)];
    expect(_stage(a.reversed.toList()), _stage(a));
  });
}
