import 'dart:convert';

import '../data/local_database.dart';
import 'engagement_logic.dart';

/// Everything the main screen shows about habits, for the current account.
class EngagementSnapshot {
  const EngagementSnapshot({
    required this.settings,
    required this.streak,
    required this.today,
    required this.dueSoon,
    required this.nextReviews,
  });

  final EngagementSettings settings;
  final StreakSummary streak;
  final GoalProgress today;

  /// Words due now or within the next 24 hours.
  final int dueSoon;

  /// Local next-review times (null = due) used to plan reminder texts.
  final List<DateTime?> nextReviews;
}

/// Loads engagement stats from the local database, scoped to the signed-in
/// account (or the signed-out learner) so a shared family device keeps each
/// learner's streak and goal apart.
class EngagementRepository {
  EngagementRepository({required this.database, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final LocalDatabase database;
  final DateTime Function() clock;

  static const _settingsKey = 'engagement.settings';

  Future<String?> _currentUserId() async =>
      (await database.loadUserSession())?.userId;

  Future<String> _settingsKeyForCurrentUser() async =>
      '$_settingsKey.${await _currentUserId() ?? 'anonymous'}';

  Future<EngagementSettings> loadSettings() async {
    final raw = await database.getSetting(await _settingsKeyForCurrentUser());
    if (raw == null || raw.isEmpty) return const EngagementSettings();
    try {
      return EngagementSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const EngagementSettings();
    }
  }

  Future<void> saveSettings(EngagementSettings settings) async {
    await database.setSetting(
        await _settingsKeyForCurrentUser(), jsonEncode(settings.toJson()));
  }

  Future<EngagementSnapshot> load({required String language}) async {
    final now = clock();
    final settings = await loadSettings();
    final studyTimes =
        (await database.studyEventTimesMs(ownerUserId: await _currentUserId()))
            .map(_localTime)
            .toList();
    final nextReviews = (await database.reviewScheduleMs(language: language))
        .map((ms) => ms <= 0 ? null : _localTime(ms))
        .toList();
    return EngagementSnapshot(
      settings: settings,
      streak: computeStreak(studyTimes, now),
      today: GoalProgress(
          done: countToday(studyTimes, now), goal: settings.dailyGoal),
      dueSoon: countDueBy(nextReviews, now.add(const Duration(hours: 24))),
      nextReviews: nextReviews,
    );
  }

  static DateTime _localTime(int epochMs) =>
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
}
