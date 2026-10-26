import 'package:expat8_language_app/src/engagement/engagement_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wall-clock times are built with DateTime.utc so the tests do not depend
  // on the machine's zone; the logic only reads the calendar fields.
  DateTime at(int month, int day, [int hour = 12, int minute = 0]) =>
      DateTime.utc(2026, month, day, hour, minute);

  group('computeStreak', () {
    test('is empty without study', () {
      final streak = computeStreak(const [], at(3, 10));
      expect(streak.current, 0);
      expect(streak.best, 0);
      expect(streak.studiedToday, isFalse);
      expect(streak.atRisk, isFalse);
    });

    test('counts consecutive days ending today', () {
      final streak = computeStreak(
          [at(3, 8), at(3, 9), at(3, 9, 18), at(3, 10, 7)], at(3, 10, 20));
      expect(streak.current, 3);
      expect(streak.best, 3);
      expect(streak.studiedToday, isTrue);
      expect(streak.atRisk, isFalse);
    });

    test('stays alive (at risk) until today ends', () {
      final streak = computeStreak([at(3, 8), at(3, 9)], at(3, 10, 21));
      expect(streak.current, 2);
      expect(streak.studiedToday, isFalse);
      expect(streak.atRisk, isTrue);
    });

    test('breaks after a missed day but keeps the best run', () {
      final streak = computeStreak(
          [at(3, 1), at(3, 2), at(3, 3), at(3, 4), at(3, 7)], at(3, 9));
      expect(streak.current, 0);
      expect(streak.best, 4);
    });

    test('splits days at local midnight, not after 24 hours', () {
      // 23:59 and 00:01 are two minutes apart but on two calendar days.
      final streak =
          computeStreak([at(3, 9, 23, 59), at(3, 10, 0, 1)], at(3, 10, 8));
      expect(streak.current, 2);
    });

    test('crosses month and year boundaries', () {
      final streak = computeStreak([
        DateTime.utc(2025, 12, 31, 22),
        DateTime.utc(2026, 1, 1, 9),
        DateTime.utc(2026, 1, 2, 9),
      ], DateTime.utc(2026, 1, 2, 23));
      expect(streak.current, 3);
    });

    test('is unaffected by 23- and 25-hour DST days', () {
      // Local (non-UTC) wall clock: calendar fields are all that matter.
      final days = [
        for (var d = 25; d <= 31; d++) DateTime(2026, 3, d, 0, 30),
        for (var d = 24; d <= 26; d++) DateTime(2026, 10, d, 23, 30),
      ];
      expect(computeStreak(days, DateTime(2026, 3, 31, 12)).current, 7);
      expect(computeStreak(days, DateTime(2026, 10, 26, 23, 45)).current, 3);
    });

    test('uses the learner time zone when times are converted to local', () {
      // 23:30 UTC on Mar 9 is Mar 10 for a learner in Vietnam (UTC+7).
      const vietnam = Duration(hours: 7);
      final events = [
        DateTime.utc(2026, 3, 9, 1).add(vietnam),
        DateTime.utc(2026, 3, 9, 23, 30).add(vietnam),
      ];
      final now = DateTime.utc(2026, 3, 10, 2).add(vietnam);
      final streak = computeStreak(events, now);
      expect(streak.current, 2);
      expect(streak.studiedToday, isTrue);
      expect(countToday(events, now), 1);
    });
  });

  test('countToday counts only events on today\'s date', () {
    expect(
      countToday(
          [at(3, 9, 23, 59), at(3, 10, 0), at(3, 10, 23, 59)], at(3, 10, 12)),
      2,
    );
  });

  test('countDueBy treats unscheduled words as due', () {
    final cutoff = at(3, 11, 12);
    expect(countDueBy([null, at(3, 1), cutoff, at(3, 11, 13)], cutoff), 3);
  });

  group('GoalProgress', () {
    test('reports fraction and remaining', () {
      const progress = GoalProgress(done: 5, goal: 20);
      expect(progress.fraction, 0.25);
      expect(progress.remaining, 15);
      expect(progress.reached, isFalse);
    });

    test('caps at the goal', () {
      const progress = GoalProgress(done: 31, goal: 30);
      expect(progress.fraction, 1);
      expect(progress.remaining, 0);
      expect(progress.reached, isTrue);
    });
  });

  group('EngagementSettings', () {
    test('defaults to a 20-card goal and an 20:00 reminder that is off', () {
      const settings = EngagementSettings();
      expect(settings.dailyGoal, 20);
      expect(settings.reminderHour, 20);
      expect(settings.reminderMinute, 0);
      expect(settings.reminderEnabled, isFalse);
    });

    test('round-trips JSON and rejects bad values', () {
      const settings = EngagementSettings(
          dailyGoal: 50, reminderEnabled: true, reminderHour: 7);
      expect(EngagementSettings.fromJson(settings.toJson()), settings);
      expect(
        EngagementSettings.fromJson(
            {'daily_goal': -1, 'reminder_hour': 30, 'reminder_enabled': 'x'}),
        const EngagementSettings(),
      );
    });
  });

  group('planReminders', () {
    const on = EngagementSettings(reminderEnabled: true);
    const notStarted = GoalProgress(done: 0, goal: 20);

    test('is empty when reminders are off', () {
      expect(
        planReminders(
          now: at(3, 10, 9),
          settings: const EngagementSettings(),
          streak: StreakSummary.empty,
          today: notStarted,
          nextReviews: const [],
        ),
        isEmpty,
      );
    });

    test('warns about a streak at risk tonight, then plain reminders', () {
      final slots = planReminders(
        now: at(3, 10, 9),
        settings: on,
        streak: const StreakSummary(current: 4, best: 6, studiedToday: false),
        today: notStarted,
        nextReviews: [at(3, 10, 8), at(3, 11, 19), null],
      );
      expect(slots, hasLength(reminderDaysAhead));
      expect(slots.first.at, at(3, 10, 20));
      expect(slots.first.title, 'Your 4-day streak ends tonight');
      expect(slots.first.body, '2 words are due for review.');
      expect(slots[1].title, 'Time for a quick review');
      expect(slots[1].body, '3 words are due for review.');
    });

    test('skips today once the goal is reached and cheers tomorrow', () {
      final slots = planReminders(
        now: at(3, 10, 9),
        settings: on,
        streak: const StreakSummary(current: 5, best: 5, studiedToday: true),
        today: const GoalProgress(done: 20, goal: 20),
        nextReviews: const [],
      );
      expect(slots.first.at, at(3, 11, 20));
      expect(slots.first.title, 'Keep your 5-day streak going');
      expect(slots.first.body, contains('your goal is 20 a day'));
      expect(slots, hasLength(reminderDaysAhead - 1));
    });

    test('starts tomorrow when today\'s time has passed', () {
      final slots = planReminders(
        now: at(3, 10, 21),
        settings: on,
        streak: StreakSummary.empty,
        today: notStarted,
        nextReviews: const [],
      );
      expect(slots.first.at, at(3, 11, 20));
    });
  });
}
