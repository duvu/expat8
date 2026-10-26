import 'dart:math';

import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/review/review_exercise.dart';
import 'package:expat8_language_app/src/ui/review_exercise_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyWord word(
  String term, {
  String? meaning,
  String example = '',
  String language = 'en',
  String entryType = 'word',
}) {
  final at = DateTime.utc(2026, 1, 1);
  return VocabularyWord(
    localId: term,
    serverWordId: term,
    term: term,
    language: language,
    meaningVi: meaning ?? 'nghĩa $term',
    ipa: '/$term/',
    vietnamesePronunciation: '',
    example: example,
    exampleVi: 'ví dụ',
    difficulty: 'B1',
    topics: const [],
    status: WordStatus.review,
    createdAt: at,
    updatedAt: at,
    entryType: entryType,
  );
}

final pool = [
  for (final t in ['river', 'apple', 'brave', 'quiet']) word(t)
];

void main() {
  test('blanks the whole word only', () {
    expect(blankedExample(word('art', example: 'Smart art lovers met.')),
        'Smart ___ lovers met.');
    expect(blankedExample(word('art', example: 'Smart people met.')), isNull);
  });

  test('every exercise is answerable and its choices are distinct', () {
    final target = word('resilient',
        example: 'She stayed resilient during the long project.');
    final kinds = <ReviewExerciseKind>{};
    for (var seed = 0; seed < 40; seed++) {
      final e = buildReviewExercise(target, [...pool, target],
          random: Random(seed), canListen: true)!;
      kinds.add(e.kind);
      if (e.kind == ReviewExerciseKind.typeWord) {
        expect(e.choices, isEmpty);
        expect(e.answer, 'resilient');
      } else {
        expect(e.choices, hasLength(4));
        expect(e.choices.toSet(), hasLength(4));
        expect(e.choices.where((c) => c == e.answer), hasLength(1));
      }
      if (e.kind == ReviewExerciseKind.fillBlank) {
        expect(e.blankedExample, contains('___'));
        expect(e.blankedExample, isNot(contains('resilient')));
      }
    }
    expect(kinds, ReviewExerciseKind.values.toSet());
  });

  test('without enough distractors only typing remains; never for Chinese', () {
    final lonely =
        buildReviewExercise(word('river'), [word('apple')], random: Random(1));
    expect(lonely?.kind, ReviewExerciseKind.typeWord);
    expect(
        buildReviewExercise(word('你好', language: 'zh'), const [],
            random: Random(1)),
        isNull);
  });

  test('typed answers: exact, one typo, wrong', () {
    expect(checkTypedAnswer(' Resilient ', 'resilient'), TypedAnswer.exact);
    expect(checkTypedAnswer('resilent', 'resilient'), TypedAnswer.nearMiss);
    expect(checkTypedAnswer('resolute', 'resilient'), TypedAnswer.wrong);
    // Short words need the exact spelling.
    expect(checkTypedAnswer('cat', 'car'), TypedAnswer.wrong);
  });

  test('grading never awards too_easy', () {
    const fast = Duration(seconds: 3);
    expect(
        gradeReviewAnswer(correct: false, elapsed: fast), StudyRating.tooHard);
    expect(gradeReviewAnswer(correct: true, elapsed: fast), StudyRating.easy);
    expect(
        gradeReviewAnswer(correct: true, elapsed: const Duration(seconds: 20)),
        StudyRating.hard);
    expect(gradeReviewAnswer(correct: true, elapsed: fast, nearMiss: true),
        StudyRating.hard);
  });

  testWidgets('a wrong choice shows the answer, then continues',
      (tester) async {
    final answers = <ReviewAnswer>[];
    var continued = false;
    final exercise = ReviewExercise(
      kind: ReviewExerciseKind.chooseMeaning,
      word: word('resilient', meaning: 'kiên cường'),
      answer: 'kiên cường',
      choices: const [
        'nghĩa river',
        'kiên cường',
        'nghĩa apple',
        'nghĩa brave'
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewExerciseView(
            exercise: exercise,
            onAnswered: (a) async => answers.add(a),
            onContinue: () => continued = true,
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('review-choice-0')));
    await tester.pump();
    expect(answers.single.correct, isFalse);
    expect(find.byKey(const ValueKey('review-feedback')), findsOneWidget);
    expect(find.text('resilient — kiên cường'), findsOneWidget);

    // Answering again is ignored.
    await tester.tap(find.byKey(const ValueKey('review-choice-1')));
    expect(answers, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('review-continue')));
    expect(continued, isTrue);
  });

  testWidgets('typing with one typo counts as nearly right', (tester) async {
    final answers = <ReviewAnswer>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewExerciseView(
            exercise: ReviewExercise(
                kind: ReviewExerciseKind.typeWord,
                word: word('resilient'),
                answer: 'resilient'),
            onAnswered: (a) async => answers.add(a),
            onContinue: () {},
          ),
        ),
      ),
    ));
    await tester.enterText(
        find.byKey(const ValueKey('review-type-field')), 'resilent');
    await tester.tap(find.byKey(const ValueKey('review-check')));
    await tester.pump();
    expect(answers.single.correct, isTrue);
    expect(answers.single.nearMiss, isTrue);
    expect(find.text('Almost! Check the spelling'), findsOneWidget);
  });
}
