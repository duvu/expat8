import 'package:flutter/foundation.dart';

import 'engagement_logic.dart';
import 'engagement_repository.dart';
import 'reminder_service.dart';

/// Keeps the main screen's streak/goal/due-soon numbers fresh and the
/// reminder schedule in step with them.
class EngagementController extends ChangeNotifier {
  EngagementController({
    required this.repository,
    this.reminders = const NoopReminderScheduler(),
  });

  final EngagementRepository repository;
  final ReminderScheduler reminders;

  EngagementSnapshot? _snapshot;
  EngagementSnapshot? get snapshot => _snapshot;

  String _language = 'en';
  Future<void>? _refreshing;
  bool _refreshAgain = false;
  List<ReminderSlot> _scheduled = const [];
  bool _disposed = false;

  /// Reloads stats for [language]. Calls arriving while a refresh runs are
  /// coalesced into one follow-up refresh.
  Future<void> refresh({String? language}) {
    if (language != null) _language = language;
    if (_refreshing != null) {
      _refreshAgain = true;
      return _refreshing!;
    }
    return _refreshing = _runRefresh();
  }

  Future<void> _runRefresh() async {
    try {
      do {
        _refreshAgain = false;
        final snapshot = await repository.load(language: _language);
        if (_disposed) return;
        _snapshot = snapshot;
        notifyListeners();
        await _reschedule(snapshot);
      } while (_refreshAgain && !_disposed);
    } on Object catch (error) {
      // Stats are decorative: a failed read must never break studying.
      debugPrint('Engagement refresh failed: $error');
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _reschedule(EngagementSnapshot snapshot) async {
    final slots = planReminders(
      now: repository.clock(),
      settings: snapshot.settings,
      streak: snapshot.streak,
      today: snapshot.today,
      nextReviews: snapshot.nextReviews,
    );
    if (listEquals(slots, _scheduled)) return;
    _scheduled = slots;
    await reminders.replaceAll(slots);
  }

  /// Saves [settings] for the current account. Turning reminders on asks for
  /// notification permission; when it is denied reminders stay off and this
  /// returns false.
  Future<bool> updateSettings(EngagementSettings settings) async {
    final current = _snapshot?.settings ?? await repository.loadSettings();
    var next = settings;
    var granted = true;
    if (settings.reminderEnabled && !current.reminderEnabled) {
      granted = await reminders.requestPermission();
      if (!granted) next = settings.copyWith(reminderEnabled: false);
    }
    await repository.saveSettings(next);
    await refresh();
    return granted;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
