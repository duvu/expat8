import 'dart:math';

import 'package:expat8_language_app/src/games/english/english_quiz.dart';
import 'package:expat8_language_app/src/games/english/sentence_builder.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/games_hub_screen.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math/math_test_utils.dart';

EnglishItem itemFor(String sentence) => EnglishLevel.values
    .expand((l) => l.bank)
    .map(EnglishItem.fromEntry)
    .firstWhere((i) => i.sentence == sentence);

EnglishRoundLog englishLog(EnglishLevel level, {int seed = 1}) {
  final skills = EnglishSkillTracker(InMemoryGameStorage());
  return EnglishRoundLog(
    level: level,
    generator:
        EnglishSource(level: level, random: Random(seed), weakItems: skills),
    skills: skills,
  );
}

void main() {
  test('every grade has a sound grammar bank', () {
    for (final level in EnglishLevel.values) {
      expect(level.bank.length, greaterThanOrEqualTo(25), reason: '$level');
      for (final entry in level.bank) {
        final item = EnglishItem.fromEntry(entry);
        expect('___'.allMatches(item.sentence).length, 1,
            reason: item.sentence);
        expect(item.distractors, isNot(contains(item.answer)),
            reason: item.sentence);
        expect(item.distractors.toSet().length, item.distractors.length);
        expect(item.completed, isNot(contains('___')));
        expect(item.hint, isNotEmpty);
        final source = EnglishSource(level: level, random: Random(2));
        final choices = source.choicesFor(item);
        expect(choices.length, 4);
        expect(choices.toSet().length, 4);
        expect(choices.where((c) => c == item.answer).length, 1);
      }
    }
  });

  test('sentences are unique across grades (they key the skill tracker)', () {
    final all = [
      for (final l in EnglishLevel.values) ...l.bank.map((e) => e.$2)
    ];
    expect(all.toSet().length, all.length);
  });

  test('the deck deals every sentence before repeating, then replays misses',
      () {
    final level = EnglishLevel.grade7;
    final skills = EnglishSkillTracker(InMemoryGameStorage());
    final source = EnglishSource(
        level: level, random: Random(3), weakItems: skills, replayShare: 0);
    final firstPass = {
      for (var i = 0; i < level.bank.length; i++) source.next().key
    };
    expect(firstPass.length, level.bank.length);

    final missed = EnglishItem.fromEntry(level.bank.first);
    skills.record(level, missed,
        correct: false, elapsed: const Duration(seconds: 9));
    final replaying = EnglishSource(
        level: level, random: Random(3), weakItems: skills, replayShare: 1);
    expect(replaying.next().key, missed.key);
  });

  test('missed English items persist apart from math facts', () async {
    final storage = InMemoryGameStorage();
    final skills = EnglishSkillTracker(storage);
    final item = EnglishItem.fromEntry(EnglishLevel.grade9.bank.first);
    skills.record(EnglishLevel.grade9, item,
        correct: false, elapsed: const Duration(seconds: 5));
    await skills.save();
    expect(storage.values.keys, contains('games.english.skills.v1'));
    final reloaded = EnglishSkillTracker(storage);
    await reloaded.load();
    expect(reloaded.weakItems(EnglishLevel.grade9).single.item.answer,
        item.answer);
  });

  test('sentence builder: order matters, mistakes cost the point', () {
    final s = SentenceSession(
        log: englishLog(EnglishLevel.grade6), random: Random(4));
    WordChip next() =>
        s.chips.firstWhere((c) => c.word == s.words[s.placed.length]);

    // A clean sentence.
    while (s.completed == 0) {
      s.tap(next());
    }
    expect(s.log.correctCount, 1);

    // A sentence with one wrong tap.
    final wrong = s.chips.firstWhere((c) => c.word != s.words.first,
        orElse: () => s.chips.first);
    if (wrong.word != s.words.first) {
      expect(s.tap(wrong), SentenceTap.wrong);
    }
    while (s.completed == 1) {
      s.tap(next());
    }
    expect(s.log.answered, 2);
    expect(s.log.correctCount, wrong.word != s.words.first ? 1 : 2);
  });

  testWidgets('Grammar Blaster: read the sentence, pick the right word',
      (tester) async {
    final ctx = mathContext(seed: 6);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.grammarBlaster),
        level: 'grade7', theme: 'Easter eggs');
    for (var i = 0; i < 3; i++) {
      final sentence = tester
          .widget<QuizPromptText>(find.byKey(const ValueKey('blaster-prompt')))
          .text;
      await tester.tap(
          find.byKey(ValueKey('blaster-choice-${itemFor(sentence).answer}')));
      await frames(tester, 3);
    }
    final score = int.parse(
        tester.widget<Text>(find.byKey(const ValueKey('math-score'))).data!);
    expect(score, greaterThanOrEqualTo(30));
    expect(await ctx.level(QuizGameKind.grammarBlaster), EnglishLevel.grade7);
  });

  testWidgets('Sentence Builder: tap the words in order', (tester) async {
    final ctx = mathContext(seed: 2);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.sentenceBuilder),
        level: 'grade8');
    final state = tester.state<State>(find.byType(SentenceBuilderScreen));
    expect(state.mounted, isTrue);

    for (var round = 0; round < 2; round++) {
      final built = tester
          .widget<Text>(find.byKey(const ValueKey('sentence-built')))
          .data!;
      final remaining = '___'.allMatches(built).length;
      // Work out the target sentence from the chips on screen and the bank.
      final chipWords = {
        for (final e in find
            .byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('sentence-chip-'))
            .evaluate())
          e.widget.key!: tester
              .widget<Text>(find.descendant(
                  of: find.byWidget(e.widget), matching: find.byType(Text)))
              .data!,
      };
      final words = chipWords.values.toList()..sort();
      final item =
          EnglishLevel.grade8.bank.map(EnglishItem.fromEntry).firstWhere((i) {
        final w = i.completed.split(' ')..sort();
        return w.join('|') == words.join('|');
      });
      expect(remaining, item.completed.split(' ').length);
      for (final word in item.completed.split(' ')) {
        final key = chipWords.entries.firstWhere((e) => e.value == word).key;
        chipWords.remove(key);
        await tester.tap(find.byKey(key));
        await tester.pump();
      }
    }
    final score = int.parse(
        tester.widget<Text>(find.byKey(const ValueKey('math-score'))).data!);
    expect(score, greaterThanOrEqualTo(20));
  });

  testWidgets('Math Race takes negative answers with the ± key (Grade 7)',
      (tester) async {
    final ctx = mathContext(seed: 11);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.race),
        level: 'grade7');
    expect(find.byKey(const ValueKey('math-key-sign')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('math-key-sign')));
    await tester.tap(find.byKey(const ValueKey('math-key-4')));
    await tester.pump();
    final line = tester
        .widget<Text>(find.descendant(
            of: find.byKey(const ValueKey('race-problem')),
            matching: find.byType(Text)))
        .data!;
    expect(line, contains('−4'));
  });

  testWidgets('hub groups games by subject and grade', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = mathContext();
    await tester.pumpWidget(
        MaterialApp(home: GamesHubScreen(storage: ctx.storage, quiz: ctx)));
    expect(find.text('Math · Grades 1–9'), findsOneWidget);
    expect(find.text('English · Grades 6–9'), findsOneWidget);
    for (final kind in QuizGameKind.values) {
      expect(find.text(kind.title), findsOneWidget, reason: kind.title);
    }
  });
}
