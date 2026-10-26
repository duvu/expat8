// Pure learner-engagement rules: streaks, daily goal, due-soon counts and the
// reminder plan. No storage, no platform calls, no clock — callers pass `now`.

/// Daily goal sizes the learner can pick (cards per day).
const List<int> dailyGoalOptions = [10, 20, 30, 50];

/// Learner choices for goal and reminder, stored per account.
class EngagementSettings {
  const EngagementSettings({
    this.dailyGoal = 20,
    // Off until the learner turns it on, which is when the notification
    // permission is asked for.
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  factory EngagementSettings.fromJson(Map<String, dynamic> json) {
    const defaults = EngagementSettings();
    int read(String key, int fallback, int min, int max) {
      final value = json[key];
      return value is int && value >= min && value <= max ? value : fallback;
    }

    return EngagementSettings(
      dailyGoal: read('daily_goal', defaults.dailyGoal, 1, 500),
      reminderEnabled: json['reminder_enabled'] is bool
          ? json['reminder_enabled'] as bool
          : defaults.reminderEnabled,
      reminderHour: read('reminder_hour', defaults.reminderHour, 0, 23),
      reminderMinute: read('reminder_minute', defaults.reminderMinute, 0, 59),
    );
  }

  final int dailyGoal;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  EngagementSettings copyWith({
    int? dailyGoal,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      EngagementSettings(
        dailyGoal: dailyGoal ?? this.dailyGoal,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );

  Map<String, dynamic> toJson() => {
        'daily_goal': dailyGoal,
        'reminder_enabled': reminderEnabled,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
      };

  @override
  bool operator ==(Object other) =>
      other is EngagementSettings &&
      other.dailyGoal == dailyGoal &&
      other.reminderEnabled == reminderEnabled &&
      other.reminderHour == reminderHour &&
      other.reminderMinute == reminderMinute;

  @override
  int get hashCode =>
      Object.hash(dailyGoal, reminderEnabled, reminderHour, reminderMinute);
}

/// Calendar-day number of a wall-clock time, independent of DST: two times
/// on the same date always share a number, consecutive dates differ by one.
int calendarDay(DateTime wallClock) =>
    DateTime.utc(wallClock.year, wallClock.month, wallClock.day)
        .millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.best,
    required this.studiedToday,
  });

  static const empty = StreakSummary(current: 0, best: 0, studiedToday: false);

  /// Consecutive study days ending today, or ending yesterday while today is
  /// still open (the streak is alive until midnight).
  final int current;
  final int best;
  final bool studiedToday;

  /// A streak exists but today has no study yet: it ends at midnight.
  bool get atRisk => current > 0 && !studiedToday;
}

/// Streak over [studyTimes] given in the learner's local wall-clock time.
StreakSummary computeStreak(Iterable<DateTime> studyTimes, DateTime now) {
  final days = studyTimes.map(calendarDay).toSet().toList()..sort();
  if (days.isEmpty) return StreakSummary.empty;

  var best = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    run = days[i] == days[i - 1] + 1 ? run + 1 : 1;
    if (run > best) best = run;
  }

  final today = calendarDay(now);
  final studiedToday = days.contains(today);
  var cursor = studiedToday ? today : today - 1;
  final daySet = days.toSet();
  var current = 0;
  while (daySet.contains(cursor)) {
    current++;
    cursor--;
  }
  return StreakSummary(
      current: current, best: best, studiedToday: studiedToday);
}

/// Number of study events on the same local date as [now].
int countToday(Iterable<DateTime> studyTimes, DateTime now) {
  final today = calendarDay(now);
  return studyTimes.where((t) => calendarDay(t) == today).length;
}

/// Words whose next review falls at or before [cutoff]. A word without a
/// schedule (null) is already due, matching the card flow.
int countDueBy(Iterable<DateTime?> nextReviews, DateTime cutoff) =>
    nextReviews.where((at) => at == null || !at.isAfter(cutoff)).length;

class GoalProgress {
  const GoalProgress({required this.done, required this.goal});

  final int done;
  final int goal;

  bool get reached => done >= goal;
  int get remaining => reached ? 0 : goal - done;
  double get fraction => goal <= 0 ? 1 : (done / goal).clamp(0, 1).toDouble();
}

/// One scheduled reminder notification.
class ReminderSlot {
  const ReminderSlot({
    required this.at,
    required this.title,
    required this.body,
  });

  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(at, title, body);
}

/// Days of reminders scheduled ahead, so learners who stop opening the app
/// still get nudged; the plan is rebuilt whenever the app refreshes stats.
const int reminderDaysAhead = 7;

/// Reminders for the next [reminderDaysAhead] days at the chosen local time.
/// Today's reminder is skipped once the daily goal is reached. The streak
/// is mentioned only on the first upcoming reminder while it is still alive.
List<ReminderSlot> planReminders({
  required DateTime now,
  required EngagementSettings settings,
  required StreakSummary streak,
  required GoalProgress today,
  required List<DateTime?> nextReviews,
}) {
  if (!settings.reminderEnabled) return const [];
  final slots = <ReminderSlot>[];
  for (var offset = 0; offset < reminderDaysAhead; offset++) {
    final at = (now.isUtc ? DateTime.utc : DateTime.new)(now.year, now.month,
        now.day + offset, settings.reminderHour, settings.reminderMinute);
    if (!at.isAfter(now)) continue;
    if (offset == 0 && today.reached) continue;

    // The streak still survives on the first reminder: today when it is
    // at risk, tomorrow when today is already studied.
    final streakAlive = streak.current > 0 &&
        ((offset == 0 && !streak.studiedToday) ||
            (offset == 1 && streak.studiedToday));
    final due = countDueBy(nextReviews, at);
    final dueText = due > 0
        ? '$due ${due == 1 ? 'word is' : 'words are'} due for review.'
        : 'Learn a few new words — your goal is ${settings.dailyGoal} a day.';
    slots.add(ReminderSlot(
      at: at,
      title: streakAlive
          ? (offset == 0
              ? 'Your ${streak.current}-day streak ends tonight'
              : 'Keep your ${streak.current}-day streak going')
          : 'Time for a quick review',
      body: dueText,
    ));
  }
  return slots;
}
