import 'package:flutter/material.dart';

/// Visual skin shared by the action games. Rules and scoring are identical.
enum GameVisualTheme {
  space(title: 'Space', icon: Icons.rocket_launch_outlined),
  easter(title: 'Easter eggs', icon: Icons.egg_alt_outlined);

  const GameVisualTheme({required this.title, required this.icon});

  final String title;
  final IconData icon;

  static GameVisualTheme fromName(String? name) => GameVisualTheme.values
      .firstWhere((t) => t.name == name, orElse: () => GameVisualTheme.space);
}

/// Bright egg colours; each egg picks one base and a deeper tone for its pattern.
const easterEggColors = [
  Color(0xFFFF8FAB), // pink
  Color(0xFFFFD166), // yellow
  Color(0xFF8EE3C8), // mint
  Color(0xFF9AD0F5), // sky
  Color(0xFFC4A7F5), // lavender
  Color(0xFFFFB38A), // peach
  Color(0xFF7BDFF2), // aqua
  Color(0xFFB8F27C), // lime
];
