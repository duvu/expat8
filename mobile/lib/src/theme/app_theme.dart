import 'package:flutter/material.dart';

/// Semantic color tokens for the app.
///
/// Access in widgets via:
/// ```dart
/// final appColors = AppColors.of(context);
/// ```
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusError,
    required this.statusNeutral,
    required this.subtleText,
    required this.ratingAgain,
    required this.ratingEasy,
    required this.severityDebug,
    required this.severityInfo,
    required this.severityWarn,
    required this.severityError,
  });

  /// Status indicator colors (passage processing, word states, etc.)
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusError;
  final Color statusNeutral;

  /// Subdued label / metadata text (replaces raw Colors.grey)
  final Color subtleText;

  /// SRS rating button colors
  final Color ratingAgain;
  final Color ratingEasy;

  /// Log-severity dot colors
  final Color severityDebug;
  final Color severityInfo;
  final Color severityWarn;
  final Color severityError;

  @override
  AppColors copyWith({
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusError,
    Color? statusNeutral,
    Color? subtleText,
    Color? ratingAgain,
    Color? ratingEasy,
    Color? severityDebug,
    Color? severityInfo,
    Color? severityWarn,
    Color? severityError,
  }) {
    return AppColors(
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusError: statusError ?? this.statusError,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      subtleText: subtleText ?? this.subtleText,
      ratingAgain: ratingAgain ?? this.ratingAgain,
      ratingEasy: ratingEasy ?? this.ratingEasy,
      severityDebug: severityDebug ?? this.severityDebug,
      severityInfo: severityInfo ?? this.severityInfo,
      severityWarn: severityWarn ?? this.severityWarn,
      severityError: severityError ?? this.severityError,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
      statusNeutral: Color.lerp(statusNeutral, other.statusNeutral, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      ratingAgain: Color.lerp(ratingAgain, other.ratingAgain, t)!,
      ratingEasy: Color.lerp(ratingEasy, other.ratingEasy, t)!,
      severityDebug: Color.lerp(severityDebug, other.severityDebug, t)!,
      severityInfo: Color.lerp(severityInfo, other.severityInfo, t)!,
      severityWarn: Color.lerp(severityWarn, other.severityWarn, t)!,
      severityError: Color.lerp(severityError, other.severityError, t)!,
    );
  }

  /// Returns the registered tokens, falling back to the brightness-matched
  /// defaults when the enclosing theme was not built by [AppTheme].
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? _dark : _light);
  }

  // ---- Predefined instances ----

  static const AppColors _light = AppColors(
    statusSuccess: Color(0xFF2E7D32), // green 800
    statusWarning: Color(0xFFE65100), // deep orange 900
    statusError: Color(0xFFC62828),   // red 800
    statusNeutral: Color(0xFF616161), // grey 700
    subtleText: Color(0xFF757575),    // grey 600
    ratingAgain: Color(0xFFB71C1C),   // red 900 (errorContainer bg is used in button style)
    ratingEasy: Color(0xFF1B5E20),    // green 900
    severityDebug: Color(0xFF78909C), // blue grey 400
    severityInfo: Color(0xFF1565C0),  // blue 800
    severityWarn: Color(0xFFE65100),  // deep orange 900
    severityError: Color(0xFFC62828), // red 800
  );

  static const AppColors _dark = AppColors(
    statusSuccess: Color(0xFF81C784), // green 300
    statusWarning: Color(0xFFFFB74D), // orange 300
    statusError: Color(0xFFEF9A9A),   // red 200
    statusNeutral: Color(0xFF9E9E9E), // grey 500
    subtleText: Color(0xFF9E9E9E),    // grey 500
    ratingAgain: Color(0xFFEF9A9A),   // red 200
    ratingEasy: Color(0xFF81C784),    // green 300
    severityDebug: Color(0xFF90A4AE), // blue grey 300
    severityInfo: Color(0xFF64B5F6),  // blue 300
    severityWarn: Color(0xFFFFB74D),  // orange 300
    severityError: Color(0xFFEF9A9A), // red 200
  );
}

/// Factory methods for app-wide [ThemeData].
///
/// Usage in [MaterialApp]:
/// ```dart
/// theme: AppTheme.light(),
/// darkTheme: AppTheme.dark(),
/// ```
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF256D5A);

  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: _seedColor),
        AppColors._light,
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
        AppColors._dark,
      );

  /// Shared look: flat tonal cards, generous touch targets (48dp), rounded
  /// inputs and buttons, and a clear title weight.
  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme;
    const radius = BorderRadius.all(Radius.circular(20));
    const buttonShape = StadiumBorder();
    const minButton = Size(64, 48);
    return base.copyWith(
      extensions: [colors],
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minButton,
          shape: buttonShape,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minButton, shape: buttonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        minVerticalPadding: 12,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    );
  }
}
