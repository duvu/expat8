import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/engagement/engagement_controller.dart';
import 'package:expat8_language_app/src/engagement/engagement_logic.dart';
import 'package:expat8_language_app/src/engagement/engagement_panel.dart';
import 'package:expat8_language_app/src/engagement/engagement_repository.dart';
import 'package:expat8_language_app/src/engagement/reminder_service.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 3, 10, 18);
  var eventCounter = 0;

  Future<LocalDatabase> openDatabase() => LocalDatabase.open(
        databaseName:
            'engagement_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );

  Future<void> rate(LocalDatabase db, DateTime when) => db.insertStudyEvent(
        StudyEvent(
          clientEventId: 'evt-${eventCounter++}',
          localWordId: 'w',
          rating: StudyRating.easy,
          occurredAt: when,
          syncStatus: SyncStatus.pending,
        ),
      );

  Future<void> signIn(LocalDatabase db, String userId) =>
      db.saveUserSession(UserSession(
          userId: userId, identifier: userId, sessionToken: 't-$userId'));

  VocabularyWord word(String id, WordStatus status, DateTime? nextReviewAt) =>
      VocabularyWord(
        localId: id,
        serverWordId: id,
        term: id,
        language: 'en',
        meaningVi: 'nghia',
        partOfSpeech: 'noun',
        ipa: '',
        vietnamesePronunciation: '',
        example: '',
        exampleVi: '',
        difficulty: 'A1',
        topics: const [],
        status: status,
        createdAt: now,
        updatedAt: now,
        nextReviewAt: nextReviewAt,
      );

  group('EngagementRepository', () {
    test('keeps streak, goal and settings per account', () async {
      final db = await openDatabase();
      final repo = EngagementRepository(database: db, clock: () => now);
      try {
        // Signed-out learner studied yesterday and today.
        await rate(db, now.subtract(const Duration(days: 1)));
        await rate(db, now);
        await repo.saveSettings(const EngagementSettings(dailyGoal: 10));

        await signIn(db, 'parent');
        await rate(db, now);
        await rate(db, now.subtract(const Duration(hours: 1)));
        await rate(db, now.subtract(const Duration(hours: 2)));

        final parent = await repo.load(language: 'en');
        expect(parent.streak.current, 1);
        expect(parent.today.done, 3);
        expect(parent.settings.dailyGoal, 20, reason: 'own default goal');

        await db.clearUserSession();
        final guest = await repo.load(language: 'en');
        expect(guest.streak.current, 2);
        expect(guest.today.done, 1);
        expect(guest.today.goal, 10);
      } finally {
        await db.close();
      }
    });

    test('counts words due now or within 24 hours', () async {
      final db = await openDatabase();
      final repo = EngagementRepository(database: db, clock: () => now);
      try {
        await db.upsertWord(word('overdue', WordStatus.review,
            now.subtract(const Duration(days: 2))));
        await db.upsertWord(word(
            'soon', WordStatus.learning, now.add(const Duration(hours: 23))));
        await db.upsertWord(word(
            'later', WordStatus.review, now.add(const Duration(hours: 25))));
        await db.upsertWord(word('new', WordStatus.newWord, null));

        final snapshot = await repo.load(language: 'en');
        expect(snapshot.dueSoon, 2);
        expect((await repo.load(language: 'zh')).dueSoon, 0);
      } finally {
        await db.close();
      }
    });
  });

  group('EngagementController', () {
    test('keeps reminders off when permission is denied', () async {
      final db = await openDatabase();
      final reminders = _FakeReminders(grant: false);
      final controller = EngagementController(
        repository: EngagementRepository(database: db, clock: () => now),
        reminders: reminders,
      );
      try {
        await controller.refresh(language: 'en');
        final granted = await controller
            .updateSettings(const EngagementSettings(reminderEnabled: true));
        expect(granted, isFalse);
        expect(reminders.permissionRequests, 1);
        expect(controller.snapshot!.settings.reminderEnabled, isFalse);
        expect(reminders.scheduled, isEmpty);
      } finally {
        controller.dispose();
        await db.close();
      }
    });

    test('schedules reminders once granted and only when the plan changes',
        () async {
      final db = await openDatabase();
      final reminders = _FakeReminders(grant: true);
      final controller = EngagementController(
        repository: EngagementRepository(database: db, clock: () => now),
        reminders: reminders,
      );
      try {
        await controller
            .updateSettings(const EngagementSettings(reminderEnabled: true));
        expect(reminders.scheduled.first.at, DateTime(2026, 3, 10, 20));
        final calls = reminders.replaceCalls;
        await controller.refresh();
        expect(reminders.replaceCalls, calls);
      } finally {
        controller.dispose();
        await db.close();
      }
    });
  });

  group('EngagementPanel', () {
    Widget host(Widget child) => MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: child),
        );

    testWidgets('shows goal progress, streak and due-soon words',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(EngagementPanel(
        snapshot: const EngagementSnapshot(
          settings: EngagementSettings(),
          streak: StreakSummary(current: 3, best: 8, studiedToday: true),
          today: GoalProgress(done: 7, goal: 20),
          dueSoon: 12,
          nextReviews: [],
        ),
        onOpenSettings: () => opened++,
      )));

      expect(find.text('7/20'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Best 8'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      final ring = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(ring.value, closeTo(0.35, 1e-9));

      await tester.tap(find.byTooltip('Daily goal & reminder'));
      expect(opened, 1);
    });

    testWidgets('nudges when the streak is at risk and cheers a met goal',
        (tester) async {
      await tester.pumpWidget(host(EngagementPanel(
        snapshot: const EngagementSnapshot(
          settings: EngagementSettings(),
          streak: StreakSummary(current: 1, best: 1, studiedToday: false),
          today: GoalProgress(done: 20, goal: 20),
          dueSoon: 0,
          nextReviews: [],
        ),
        onOpenSettings: () {},
      )));

      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('Study today!'), findsOneWidget);
      expect(find.text('Goal reached'), findsOneWidget);
    });
  });
}

class _FakeReminders implements ReminderScheduler {
  _FakeReminders({required this.grant});

  final bool grant;
  int permissionRequests = 0;
  int replaceCalls = 0;
  List<ReminderSlot> scheduled = const [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> replaceAll(List<ReminderSlot> slots) async {
    replaceCalls++;
    scheduled = slots;
  }
}
