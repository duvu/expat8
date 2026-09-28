import 'package:flutter/material.dart';

/// Word Blaster game modes (see docs/games/20260928-word-blaster-game-design.md §3).
enum WordBlasterMode {
  classic(
    title: 'Classic',
    description: 'See the Vietnamese meaning, shoot the English word.',
    icon: Icons.rocket_launch_outlined,
  ),
  reverse(
    title: 'Reverse',
    description: 'See the word, shoot its Vietnamese meaning.',
    icon: Icons.swap_horiz_rounded,
  ),
  listening(
    title: 'Listening',
    description: 'Hear the word, shoot what you heard.',
    icon: Icons.headphones_outlined,
  ),
  fillGap(
    title: 'Fill the gap',
    description: 'Complete the example sentence.',
    icon: Icons.short_text_rounded,
    minLevelIndex: 1,
  ),
  timeAttack(
    title: 'Time Attack',
    description: '60 seconds, no lives. Mistakes cost 3 seconds.',
    icon: Icons.timer_outlined,
  );

  const WordBlasterMode({
    required this.title,
    required this.description,
    required this.icon,
    this.minLevelIndex = 0,
  });

  final String title;
  final String description;
  final IconData icon;

  /// Minimum proficiency level index (A1/HSK1 = 0) needed to unlock.
  final int minLevelIndex;

  bool get hasLives => this != WordBlasterMode.timeAttack;
  bool get answersAreMeanings => this == WordBlasterMode.reverse;

  static WordBlasterMode fromName(String? name) => WordBlasterMode.values
      .firstWhere((m) => m.name == name, orElse: () => WordBlasterMode.classic);
}
