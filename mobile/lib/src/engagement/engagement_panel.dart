import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'engagement_repository.dart';
import '../theme/app_radius.dart';

/// Compact habit strip on the main learning screen: today's goal ring,
/// the study streak and how many words are about to be forgotten.
class EngagementPanel extends StatelessWidget {
  const EngagementPanel({
    required this.snapshot,
    required this.onOpenSettings,
    super.key,
  });

  final EngagementSnapshot snapshot;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final today = snapshot.today;
    final streak = snapshot.streak;
    final streakColor =
        streak.studiedToday ? colors.statusWarning : colors.statusNeutral;

    return Padding(
      key: const ValueKey('engagement-panel'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenSettings,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    key: const ValueKey('engagement-goal'),
                    leading: SizedBox.square(
                      dimension: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: today.fraction,
                            strokeWidth: 4,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: today.reached
                                ? colors.statusSuccess
                                : scheme.primary,
                          ),
                          Icon(
                            today.reached
                                ? Icons.check_rounded
                                : Icons.flag_rounded,
                            size: 16,
                            color: today.reached
                                ? colors.statusSuccess
                                : scheme.primary,
                          ),
                        ],
                      ),
                    ),
                    value: '${today.done}/${today.goal}',
                    label: today.reached ? 'Goal reached' : 'Today',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    key: const ValueKey('engagement-streak'),
                    leading: Icon(Icons.local_fire_department_rounded,
                        size: 30, color: streakColor),
                    value: '${streak.current} '
                        '${streak.current == 1 ? 'day' : 'days'}',
                    label:
                        streak.atRisk ? 'Study today!' : 'Best ${streak.best}',
                    labelColor: streak.atRisk ? colors.statusWarning : null,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    key: const ValueKey('engagement-due'),
                    leading: Icon(Icons.hourglass_bottom_rounded,
                        size: 28,
                        color: snapshot.dueSoon > 0
                            ? colors.statusError
                            : colors.statusNeutral),
                    value: '${snapshot.dueSoon}',
                    label: 'To review',
                  ),
                ),
                IconButton(
                  tooltip: 'Daily goal & reminder',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.leading,
    required this.value,
    required this.label,
    this.labelColor,
    super.key,
  });

  final Widget leading;
  final String value;
  final String label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        leading,
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor ?? AppColors.of(context).subtleText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
