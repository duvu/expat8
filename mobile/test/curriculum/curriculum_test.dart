import 'dart:convert';
import 'dart:io';

import 'package:expat8_language_app/src/curriculum/curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _skill(String id,
        {String topic = 't', int grade = 3, List<String> pre = const []}) =>
    {
      'id': id,
      'topic': topic,
      'grade': grade,
      'title': id,
      'prerequisites': pre,
      'example': {'question': '1 + 1', 'answer': '2'},
    };

Map<String, dynamic> _file(List<Map<String, dynamic>> skills) => {
      'version': 1,
      'subject': 'math',
      'topics': [
        {'id': 't', 'title': 'Topic'}
      ],
      'skills': skills,
    };

void main() {
  test('the bundled math curriculum is valid', () {
    final curriculum = Curriculum.parse(
        File('assets/curriculum/math.json').readAsStringSync());
    expect(curriculum.subject, 'math');
    expect(curriculum.skills, isNotEmpty);
    for (final grade in [3, 7]) {
      expect(curriculum.skills.where((s) => s.grade == grade), isNotEmpty,
          reason: 'grade $grade has skills');
    }
  });

  test('exposes topics, grades, prerequisites and examples', () {
    final c = Curriculum.fromJson(_file([
      _skill('math.a'),
      _skill('math.b', grade: 5, pre: ['math.a']),
    ]));
    expect(c.skill('math.b')!.grade, 5);
    expect(c.skill('math.b')!.prerequisites, ['math.a']);
    expect(c.skill('math.a')!.example.answer, '2');
    expect(c.skillsOfTopic('t').map((s) => s.id), ['math.a', 'math.b']);
    expect(c.skill('math.a')!.subject, 'math');
  });

  group('validation', () {
    void rejects(List<Map<String, dynamic>> skills, String mention) {
      expect(
        () => Curriculum.fromJson(_file(skills)),
        throwsA(isA<CurriculumException>()
            .having((e) => e.message, 'message', contains(mention))),
      );
    }

    test('duplicate ids', () {
      rejects([_skill('math.a'), _skill('math.a')], 'math.a');
    });

    test('unknown prerequisite', () {
      rejects([
        _skill('math.a', pre: ['math.zzz'])
      ], 'math.a');
    });

    test('prerequisite cycle', () {
      rejects([
        _skill('math.a', pre: ['math.b']),
        _skill('math.b', pre: ['math.a']),
      ], 'cycle');
    });

    test('missing example', () {
      final bad = _skill('math.a')..remove('example');
      rejects([bad], 'math.a');
    });

    test('skill outside the subject', () {
      rejects([_skill('science.a')], 'science.a');
    });
  });

  group('not capped by grade', () {
    final c = Curriculum.fromJson(_file([
      _skill('math.g3', grade: 3),
      _skill('math.g5', grade: 5, pre: ['math.g3']),
      _skill('math.g7', grade: 7, pre: ['math.g5']),
    ]));

    test('a skill ahead of the learner is offered once prerequisites are done',
        () {
      expect(c.unlockedBy({'math.g3'}).map((s) => s.id), ['math.g5']);
    });

    test('a weak prerequisite comes before its dependants', () {
      expect(c.unlockedBy({}).map((s) => s.id), ['math.g3']);
    });

    test('done skills are not offered again', () {
      expect(c.unlockedBy({'math.g3', 'math.g5', 'math.g7'}), isEmpty);
    });
  });

  test('re-leveling a skill keeps its id', () {
    final before = Curriculum.fromJson(_file([_skill('math.a', grade: 4)]));
    final after = Curriculum.fromJson(_file([_skill('math.a', grade: 6)]));
    expect(before.skill('math.a')!.id, after.skill('math.a')!.id);
    expect(jsonEncode(after.skill('math.a')!.grade), '6');
  });
}
