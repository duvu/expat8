import 'dart:io';
import 'dart:math';

import 'package:expat8_language_app/src/curriculum/curriculum.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_skills_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Curriculum skills whose generators are added in later steps (text
/// answers such as fractions and units). Shrink this list as they land.
const _withoutGenerator = {
  'math.frac.parts-of-whole',
  'math.measure.units',
  'math.measure.time',
  'math.geometry.perimeter',
  'math.words.one-two-step',
  'math.rational.operations',
  'math.algebra.expressions',
  'math.integers.signed-powers',
  'math.geometry.angles',
};

void main() {
  final curriculum =
      Curriculum.parse(File('assets/curriculum/math.json').readAsStringSync());

  test('every mapped skill exists in the curriculum', () {
    for (final id in MathSkill.all) {
      expect(curriculum.contains(id), isTrue, reason: id);
    }
  });

  test('every curriculum skill has a generator, or is listed as pending', () {
    final mapped = MathSkill.all.toSet();
    final missing = {
      for (final s in curriculum.skills)
        if (!mapped.contains(s.id)) s.id
    };
    expect(missing, _withoutGenerator);
  });

  test('every problem the generators make carries a curriculum skill', () {
    final seen = <String>{};
    for (final level in MathLevel.values) {
      for (final difficulty in [0.0, 0.5, 1.0]) {
        final generator = MathProblemGenerator(
            level: level, random: Random(level.index), difficulty: difficulty);
        for (var i = 0; i < 300; i++) {
          final problem = generator.next();
          expect(problem.skillId, isNotNull, reason: '${level.id}: $problem');
          expect(curriculum.contains(problem.skillId!), isTrue,
              reason: '${problem.skillId} from $problem');
          seen.add(problem.skillId!);
        }
      }
    }
    // Every mapped family is reachable from some level.
    expect(MathSkill.all.toSet().difference(seen), isEmpty);
  });

  test('skills follow the size of the numbers', () {
    expect(additionProblem(8, 7).skillId, MathSkill.addSubWithin20);
    expect(additionProblem(46, 38).skillId, MathSkill.addSubWithin100);
    expect(subtractionProblem(356, 249).skillId, MathSkill.addSubWithin1000);
    expect(additionProblem(4382, 2759).skillId, MathSkill.addSubWithin10000);
    expect(multiplicationProblem(7, 8).skillId, MathSkill.tables);
    expect(multiplicationProblem(34, 6).skillId, MathSkill.twoByOne);
    expect(multiplicationProblem(23, 14).skillId, MathSkill.twoByTwo);
    expect(divisionProblem(56, 7).skillId, MathSkill.divideFacts);
    expect(divisionProblem(156, 6).skillId, MathSkill.divideLarger);
  });

  test('skillId survives a JSON round trip, and old JSON still loads', () {
    final problem = multiplicationProblem(7, 8);
    expect(MathProblem.fromJson(problem.toJson()).skillId, MathSkill.tables);
    final old = Map<String, dynamic>.of(problem.toJson())..remove('skill');
    expect(MathProblem.fromJson(old).skillId, isNull);
  });
}
