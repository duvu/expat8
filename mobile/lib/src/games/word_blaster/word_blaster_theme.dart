import '../common/game_theme.dart';

export '../common/game_theme.dart' show easterEggColors;

/// Word Blaster uses the shared game skins.
typedef WordBlasterTheme = GameVisualTheme;

/// Egg width factor for a label: short words give small eggs, long words big
/// ones (3 letters ≈ 0.75, 12+ letters ≈ 1.45).
double eggScaleForLength(int length) =>
    0.75 + ((length.clamp(3, 12) - 3) / 9) * 0.7;
