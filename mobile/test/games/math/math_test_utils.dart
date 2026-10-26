import 'dart:math';

import 'package:expat8_language_app/src/games/common/game_audio.dart';
import 'package:expat8_language_app/src/games/common/game_settings.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Independent evaluator for the problem texts the generator produces.
int evaluate(String text) {
  final tokens = text.split(' ');
  int apply(int a, String op, int b) => switch (op) {
        '+' => a + b,
        '−' => a - b,
        '×' => a * b,
        '÷' => a ~/ b,
        _ => throw ArgumentError(op),
      };
  if (tokens.length == 3) {
    return apply(int.parse(tokens[0]), tokens[1], int.parse(tokens[2]));
  }
  // a + b × c  or  b × c − a (multiplication first).
  final values = [
    int.parse(tokens[0]),
    int.parse(tokens[2]),
    int.parse(tokens[4])
  ];
  if (tokens[1] == '×') {
    return apply(values[0] * values[1], tokens[3], values[2]);
  }
  return apply(values[0], tokens[1], values[1] * values[2]);
}

QuizGameContext mathContext({int seed = 1, GameStorage? storage}) {
  final store = storage ?? InMemoryGameStorage();
  final settings = GameSettings(store);
  return QuizGameContext(
    storage: store,
    settings: settings,
    audio: GameAudio.silent(settings),
    randomFactory: () => Random(seed),
  );
}

/// Game loops keep scheduling frames: advance by time, never pumpAndSettle.
Future<void> frames(WidgetTester tester, int count,
    [Duration step = const Duration(milliseconds: 16)]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

/// Settles route transitions while a game loop may be running.
Future<void> settle(WidgetTester tester) => frames(tester, 30);

/// Label of the token currently outlined as the target.
String targetLabel(WidgetTester tester) => tester
    .widgetList<QuizToken>(find.byType(QuizToken))
    .firstWhere((t) => t.highlight)
    .label;

Future<void> openPlay(WidgetTester tester, Widget home,
    {String level = 'grade1', String theme = 'Space'}) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('math-level-$level')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(theme));
  await tester.pumpAndSettle();
  await tapScrolled(tester, find.byKey(const ValueKey('math-play')));
  await settle(tester);
}

/// Scrolls the home screen until [finder] is built and visible, then taps it.
Future<void> tapScrolled(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
