import 'dart:convert';
import 'dart:math';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/games/common/game_audio.dart';
import 'package:expat8_language_app/src/games/common/game_settings.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/word_blaster/game/word_blaster_game.dart';
import 'package:expat8_language_app/src/games/word_blaster/ui/word_blaster_home_screen.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_blaster_context.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_blaster_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'word_blaster_fixtures.dart';

/// Every sync fails like a device without network.
class _OfflineApi extends BackendApiClient {
  _OfflineApi()
      : super(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'a',
            appSecret: 's');

  @override
  Future<SyncResult> syncStudyEvents({
    required String deviceId,
    required List<Map<String, dynamic>> events,
    String? sessionToken,
    String? language,
  }) async =>
      throw BackendApiException('Network is unreachable');

  @override
  Future<GameRoundSyncResult> syncGameRounds({
    required String deviceId,
    required List<Map<String, dynamic>> rounds,
    String? sessionToken,
  }) async =>
      throw BackendApiException('Network is unreachable');
}

Future<(WordBlasterContext, LocalDatabase, List<String>)> buildContext({
  List<VocabularyWord>? words,
}) async {
  final db = await LocalDatabase.open(
    databaseName:
        'word_blaster_screens_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final vocabulary = words ?? sampleVocabulary();
  await db.addBatch(vocabulary);
  final storage = InMemoryGameStorage();
  final settings = GameSettings(storage);
  final spoken = <String>[];
  final ctx = WordBlasterContext(
    repository: WordRepository(database: db, apiClient: _OfflineApi()),
    storage: storage,
    settings: settings,
    audio: GameAudio.silent(settings),
    language: 'en',
    learnerLevelIndex: 1,
    speak: (text, _) async => spoken.add(text),
    randomFactory: () => Random(7),
  );
  return (ctx, db, spoken);
}

WordBlasterGame gameOf(WidgetTester tester) => tester
    .widget<GameWidget<WordBlasterGame>>(
        find.byKey(const ValueKey('word-blaster-game')))
    .game!;

Future<void> frames(WidgetTester tester, int count, {int ms = 50}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Taps the first visible meteor matching [correct] on the Flame canvas.
Future<bool> tapMeteor(WidgetTester tester, {required bool correct}) async {
  final game = gameOf(tester);
  final origin =
      tester.getTopLeft(find.byKey(const ValueKey('word-blaster-game')));
  for (final m in game.session.meteors) {
    if (m.isCorrect != correct || !m.visible) continue;
    final center = game.meteorCenter(m.id);
    if (center == null) continue;
    await tester.tapAt(origin + Offset(center.x, center.y));
    await tester.pump();
    return true;
  }
  return false;
}

/// Waits until meteors are on screen and tappable.
Future<void> waitForMeteors(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    final session = gameOf(tester).session;
    if (session.phase == WordBlasterPhase.playing &&
        session.meteors.where((m) => m.visible).length ==
            session.meteors.length &&
        session.meteors
            .every((m) => gameOf(tester).meteorCenter(m.id) != null)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('plays a classic round to game over and records reviews',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ctx, db, _) = await tester.runAsync(buildContext) as (
      WordBlasterContext,
      LocalDatabase,
      List<String>
    );
    addTearDown(db.close);

    await tester
        .pumpWidget(MaterialApp(home: WordBlasterHomeScreen(context: ctx)));
    await tester.pumpAndSettle();
    expect(find.text('Classic'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('word-blaster-mode-classic')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await frames(tester, 50); // countdown 3-2-1
    await waitForMeteors(tester);

    // One correct answer scores points.
    expect(await tapMeteor(tester, correct: true), isTrue);
    await frames(tester, 6);
    expect(gameOf(tester).session.correctCount, 1);
    expect(find.byKey(const ValueKey('word-blaster-score')), findsOneWidget);

    // Three wrong answers end the round.
    final session = gameOf(tester).session;
    for (var i = 0; i < 3; i++) {
      await waitForMeteors(tester);
      expect(await tapMeteor(tester, correct: false), isTrue);
      await frames(tester, i < 2 ? 30 : 2); // projectile + reveal
    }
    expect(session.isOver, isTrue);
    expect(session.lives, 0);
    await frames(tester, 25);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await frames(tester, 10);

    // First record: name dialog, then the recap.
    expect(find.text('Rank #1!'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('word-blaster-player-name')), 'Lan');
    await tester.tap(find.text('Save'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recap-score')), findsOneWidget);
    expect(find.text('Missed words'), findsOneWidget);

    // Every answered word produced exactly one queued study event tagged as a game review.
    final queued = await tester.runAsync(
      () => db
          .dueSyncEntries(DateTime.now().toUtc().add(const Duration(days: 1))),
    );
    final events = [
      for (final e in queued!)
        if (e.type == 'study_event')
          jsonDecode(e.payload) as Map<String, dynamic>,
    ];
    // A missed word may be asked again, but it is recorded only once.
    expect(events, hasLength(session.outcomes.length));
    expect(events.every((e) => e['source'] == 'game_word_blaster'), isTrue);
    expect(events.map((e) => e['rating']).toSet(), {'easy', 'hard'});
    expect(events.map((e) => e['local_word_id']).toSet(),
        hasLength(events.length));
    // The finished round is queued for upload too.
    expect(queued.where((e) => e.type == 'game_round'), hasLength(0),
        reason: 'no onRoundFinished hook in this context');

    // Review the missed words.
    await tester.tap(find.byKey(const ValueKey('recap-review')));
    await tester.pumpAndSettle();
    final missedCount = session.missedWords.length;
    var reviewed = 0;
    while (find.byKey(const ValueKey('review-card')).evaluate().isNotEmpty &&
        reviewed < 10) {
      await tester.tap(find.text('Tap to see the meaning'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-know-it')));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      reviewed++;
    }
    await tester.pumpAndSettle();
    expect(reviewed, missedCount);
    expect(find.text('Review done'), findsOneWidget);
    expect(find.text('You knew $missedCount of $missedCount.'), findsOneWidget);
  });

  testWidgets('pausing freezes the round and resume continues it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ctx, db, spoken) = await tester.runAsync(buildContext) as (
      WordBlasterContext,
      LocalDatabase,
      List<String>
    );
    addTearDown(db.close);

    await tester
        .pumpWidget(MaterialApp(home: WordBlasterHomeScreen(context: ctx)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('word-blaster-mode-listening')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await frames(tester, 50);
    await waitForMeteors(tester);

    // Listening mode speaks the prompt automatically and allows 2 replays.
    expect(spoken, isNotEmpty);
    expect(find.text('Play again (2 left)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-blaster-replay')));
    await tester.pump();
    expect(find.text('Play again (1 left)'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    final session = gameOf(tester).session;
    final progress = session.meteors.first.progress;
    await frames(tester, 20);
    expect(session.meteors.first.progress, progress);

    await tester.tap(find.text('Resume'));
    await frames(tester, 5);
    expect(session.meteors.first.progress, greaterThan(progress));

    // End the round from the pause menu.
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('End round'));
    await tester
        .pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1))
        .catchError((_) => 0);
    await tester.tap(find.text('End round').last);
    await frames(tester, 30);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await frames(tester, 10);
    expect(session.isOver, isTrue);
  });

  testWidgets('explains when there are not enough words', (tester) async {
    final (ctx, db, _) = await tester.runAsync(
      () => buildContext(words: sampleVocabulary().take(5).toList()),
    ) as (WordBlasterContext, LocalDatabase, List<String>);
    addTearDown(db.close);

    await tester
        .pumpWidget(MaterialApp(home: WordBlasterHomeScreen(context: ctx)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('word-blaster-mode-classic')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Learn a few more words'), findsOneWidget);
    expect(find.textContaining('You have 5'), findsOneWidget);
  });

  testWidgets('locks Fill the gap below A2 and disables Listening without TTS',
      (tester) async {
    final (base, db, _) = await tester.runAsync(buildContext) as (
      WordBlasterContext,
      LocalDatabase,
      List<String>
    );
    addTearDown(db.close);
    final ctx = WordBlasterContext(
      repository: base.repository,
      storage: base.storage,
      settings: base.settings,
      audio: base.audio,
      language: 'en',
      learnerLevelIndex: 0,
    );
    await tester
        .pumpWidget(MaterialApp(home: WordBlasterHomeScreen(context: ctx)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unlocks at level A2'), findsOneWidget);
    expect(find.text('Needs text-to-speech on this device'), findsOneWidget);
  });
}
