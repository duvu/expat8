import 'package:flutter/material.dart';

// Learning-language and study-level pickers shown in the app bar.
const Map<String, String> kLearningLanguageLabels = {
  'en': 'English',
  'zh': 'Chinese',
  'vi': 'Vietnamese',
};

class LearningLanguageSelector extends StatelessWidget {
  const LearningLanguageSelector({
    required this.currentLanguage,
    required this.supportedLanguages,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  final String currentLanguage;
  final List<String> supportedLanguages;
  final bool isLoading;
  final Future<void> Function(String language) onChanged;

  String _labelFor(String language) {
    return kLearningLanguageLabels[language] ?? language.toUpperCase();
  }

  Future<void> _showPicker(BuildContext context) async {
    if (isLoading) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Choose learning language',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final language in supportedLanguages)
                ListTile(
                  title: Text(_labelFor(language)),
                  subtitle: Text(language.toUpperCase()),
                  trailing: language == currentLanguage
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () => Navigator.of(context).pop(language),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != currentLanguage) {
      await onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _labelFor(currentLanguage);
    return Tooltip(
      message: 'Change learning language',
      child: Semantics(
        button: true,
        label: 'Learning language: $label. Change',
        excludeSemantics: true,
        child: ActionChip(
          avatar: const Icon(Icons.translate_rounded, size: 18),
          label: Text(label),
          onPressed: isLoading ? null : () => _showPicker(context),
          labelStyle: theme.textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class ProficiencyLevelLabel extends StatelessWidget {
  const ProficiencyLevelLabel({
    required this.scale,
    required this.level,
    this.studyLevel,
    this.onTap,
    super.key,
  });

  final String scale;
  final String level;

  /// Level picked for this session when it differs from [level]; shown instead.
  final String? studyLevel;

  /// Opens the level picker; the chip is not interactive when null.
  final VoidCallback? onTap;

  String get formattedLevel => formatStudyLevel(scale, level);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overridden = studyLevel != null;
    final background =
        overridden ? scheme.tertiaryContainer : scheme.primaryContainer;
    final foreground =
        overridden ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;
    final label = overridden
        ? 'Studying ${formatStudyLevel(scale, studyLevel!)}'
        : 'Level $formattedLevel';
    return Center(
      child: Semantics(
        button: onTap != null,
        label: '$label. Change study level',
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('study-level-chip'),
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_drop_down_rounded,
                        size: 20, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatStudyLevel(String scale, String level) {
  if (scale.toLowerCase() == 'hsk') {
    return level.toUpperCase().startsWith('HSK')
        ? level.toUpperCase()
        : 'HSK$level';
  }
  return level.toUpperCase();
}

/// Bottom sheet that lets the learner study a different level for this session.
class StudyLevelSheet extends StatelessWidget {
  const StudyLevelSheet({
    required this.scale,
    required this.ownLevel,
    required this.currentLevel,
    required this.options,
    super.key,
  });

  final String scale;
  final String ownLevel;
  final String currentLevel;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a level to study', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Your level is ${formatStudyLevel(scale, ownLevel)}. '
              'This choice only applies to this session.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final level in options)
              ListTile(
                key: Key('study-level-$level'),
                contentPadding: EdgeInsets.zero,
                title: Text(formatStudyLevel(scale, level) +
                    (level == ownLevel ? '  ·  your level' : '')),
                trailing: level == currentLevel
                    ? Icon(Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(level),
              ),
          ],
        ),
      ),
    );
  }
}
