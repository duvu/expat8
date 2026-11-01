import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_radius.dart';

/// The shell of every study card: a raised card topped by a brand accent
/// strip tinted toward the word's level.
class StudyCardFrame extends StatelessWidget {
  const StudyCardFrame({
    required this.level,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    super.key,
  });

  final String level;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                scheme.primary,
                AppTheme.levelColor(level),
                AppTheme.brandSpark,
              ]),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A CEFR/HSK level in its ladder colour.
class LevelBadge extends StatelessWidget {
  const LevelBadge({required this.level, super.key});

  final String level;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('word-level-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.levelColor(level),
          borderRadius: AppRadius.control,
        ),
        child: Text(
          level,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
}
