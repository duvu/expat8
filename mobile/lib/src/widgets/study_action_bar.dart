import 'package:flutter/material.dart';

/// Big, labelled buttons for the three study actions, so learners do not need
/// to discover the swipe gestures (which still work as shortcuts).
class StudyActionBar extends StatelessWidget {
  const StudyActionBar({
    required this.enabled,
    required this.onDifficult,
    required this.onNext,
    required this.onRemembered,
    this.nextLabel = 'Next',
    this.swipeHint,
    super.key,
  });

  final bool enabled;
  final Future<void> Function() onDifficult;
  final Future<void> Function() onNext;
  final Future<void> Function() onRemembered;
  final String nextLabel;
  final String? swipeHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
            top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _StudyButton(
                  key: const ValueKey('study-difficult'),
                  icon: Icons.replay_rounded,
                  label: 'Difficult',
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                  onPressed: enabled ? onDifficult : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudyButton(
                  key: const ValueKey('study-remembered'),
                  icon: Icons.check_rounded,
                  label: 'Remembered',
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                  onPressed: enabled ? onRemembered : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudyButton(
                  key: const ValueKey('study-next'),
                  icon: Icons.arrow_forward_rounded,
                  label: nextLabel,
                  background: scheme.primary,
                  foreground: scheme.onPrimary,
                  onPressed: enabled ? onNext : null,
                ),
              ),
            ],
          ),
          if (swipeHint != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe_rounded, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    swipeHint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudyButton extends StatelessWidget {
  const _StudyButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    final fg = enabled ? foreground : scheme.outline;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? background : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
