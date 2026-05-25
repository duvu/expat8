import 'package:flutter/material.dart';

/// Semantic color tokens for the app.
///
/// Access in widgets via:
/// ```dart
/// final appColors = Theme.of(context).extension<AppColors>()!;
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

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      useMaterial3: true,
      extensions: const [AppColors._light],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      extensions: const [AppColors._dark],
    );
  }
}
