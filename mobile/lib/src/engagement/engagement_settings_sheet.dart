import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'engagement_controller.dart';
import 'engagement_logic.dart';

/// Opens the daily goal & reminder sheet for the current account.
Future<void> showEngagementSettingsSheet(
  BuildContext context,
  EngagementController controller,
) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EngagementSettingsSheet(controller: controller),
    );

class EngagementSettingsSheet extends StatefulWidget {
  const EngagementSettingsSheet({required this.controller, super.key});

  final EngagementController controller;

  @override
  State<EngagementSettingsSheet> createState() =>
      _EngagementSettingsSheetState();
}

class _EngagementSettingsSheetState extends State<EngagementSettingsSheet> {
  bool _permissionDenied = false;

  EngagementSettings get _settings =>
      widget.controller.snapshot?.settings ?? const EngagementSettings();

  Future<void> _save(EngagementSettings settings) async {
    final granted = await widget.controller.updateSettings(settings);
    if (mounted) setState(() => _permissionDenied = !granted);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _settings.reminderHour, minute: _settings.reminderMinute),
    );
    if (picked == null) return;
    await _save(_settings.copyWith(
        reminderHour: picked.hour, reminderMinute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final settings = _settings;
        final streak = widget.controller.snapshot?.streak;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Daily goal', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('How many cards do you want to study each day?',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final goal in dailyGoalOptions)
                      ChoiceChip(
                        key: ValueKey('engagement-goal-$goal'),
                        label: Text('$goal cards'),
                        selected: settings.dailyGoal == goal,
                        onSelected: (_) =>
                            _save(settings.copyWith(dailyGoal: goal)),
                      ),
                  ],
                ),
                if (streak != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Current streak: ${streak.current} · '
                    'Best streak: ${streak.best}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.of(context).subtleText),
                  ),
                ],
                const Divider(height: 32),
                SwitchListTile(
                  key: const ValueKey('engagement-reminder-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily reminder'),
                  subtitle: const Text(
                      'A gentle nudge when words are due or your streak is at risk.'),
                  value: settings.reminderEnabled,
                  onChanged: (on) =>
                      _save(settings.copyWith(reminderEnabled: on)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: settings.reminderEnabled,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Reminder time'),
                  trailing: Text(
                    TimeOfDay(
                            hour: settings.reminderHour,
                            minute: settings.reminderMinute)
                        .format(context),
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: _pickTime,
                ),
                if (_permissionDenied)
                  Text(
                    'Notifications are blocked for this app. Allow them in '
                    'your phone settings to get reminders.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.of(context).statusError),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
