import 'package:flutter/material.dart';

import '../models/vocabulary_word.dart';

class VocabularyCardView extends StatelessWidget {
  const VocabularyCardView({required this.word, super.key});

  final VocabularyWord word;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    word.term,
                    style: textTheme.headlineMedium,
                  ),
                ),
                if (word.partOfSpeech != null)
                  Text(word.partOfSpeech!, style: textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            Text(word.meaningVi, style: textTheme.titleMedium),
            const Divider(height: 32),
            _Detail(label: 'Vietnamese reading', value: word.vietnamesePronunciation),
            _Detail(label: 'IPA', value: word.ipa),
            const SizedBox(height: 16),
            Text(word.example, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(word.exampleVi, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
