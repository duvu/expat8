import 'package:flutter/material.dart';

const Map<String, String> kLanguageNames = {
  'en': 'English',
  'zh': 'Chinese',
  'vi': 'Vietnamese',
  'en-idioms': 'English idioms',
  'zh-idioms': 'Chinese idioms',
};

String languageName(String code) => kLanguageNames[code] ?? code.toUpperCase();

/// One-tap language choice: segments for up to 3 languages, chips beyond.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    required this.languages,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Language',
    super.key,
  });

  final List<String> languages;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label!,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        if (languages.length <= 3)
          SegmentedButton<String>(
            segments: [
              for (final code in languages)
                ButtonSegment(value: code, label: Text(languageName(code))),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged:
                enabled ? (value) => onChanged(value.first) : null,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in languages)
                ChoiceChip(
                  label: Text(languageName(code)),
                  selected: code == selected,
                  onSelected: enabled ? (_) => onChanged(code) : null,
                ),
            ],
          ),
      ],
    );
  }
}
