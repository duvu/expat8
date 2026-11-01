import 'package:flutter/material.dart';
import 'app_radius.dart';

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
    statusSuccess: Color(0xFF0F8A72), // Expat8 teal
    statusWarning: Color(0xFFB7791F), // Expat8 amber
    statusError: Color(0xFFC2414B), // Expat8 danger
    statusNeutral: Color(0xFF64748B), // Expat8 muted ink
    subtleText: Color(0xFF64748B), // Expat8 muted ink
    ratingAgain: Color(0xFFC2414B), // Expat8 danger
    ratingEasy: Color(0xFF0F8A72), // Expat8 teal
    severityDebug: Color(0xFF94A3B8), // Expat8 subtle ink
    severityInfo: Color(0xFF2672A8), // Expat8 info
    severityWarn: Color(0xFFB7791F), // Expat8 amber
    severityError: Color(0xFFC2414B), // Expat8 danger
  );

  static const AppColors _dark = AppColors(
    statusSuccess: Color(0xFF34D399), // Expat8 teal dark
    statusWarning: Color(0xFFF6C453), // Expat8 amber dark
    statusError: Color(0xFFFB7185), // Expat8 danger dark
    statusNeutral: Color(0xFFA8B4C5), // Expat8 muted ink dark
    subtleText: Color(0xFFA8B4C5), // Expat8 muted ink dark
    ratingAgain: Color(0xFFFB7185), // Expat8 danger dark
    ratingEasy: Color(0xFF34D399), // Expat8 teal dark
    severityDebug: Color(0xFF718096), // Expat8 subtle ink dark
    severityInfo: Color(0xFF60A5FA), // Expat8 info dark
    severityWarn: Color(0xFFF6C453), // Expat8 amber dark
    severityError: Color(0xFFFB7185), // Expat8 danger dark
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
  /// Brand anchors from the app icon: indigo field and the teal spark.
  static const Color brandIndigo = Color(0xFF2A24AA);
  static const Color brandSpark = Color(0xFF34D399);

  static ThemeData light() => _build(
        ColorScheme.fromSeed(
            seedColor: brandIndigo, tertiary: const Color(0xFF0F8A72)),
        AppColors._light,
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
            seedColor: brandIndigo,
            tertiary: brandSpark,
            brightness: Brightness.dark),
        AppColors._dark,
      );

  /// One colour per proficiency step (CEFR A1–C2, HSK 1–6): beginner green
  /// through intermediate blue to advanced violet, so a level reads at a
  /// glance everywhere it is shown.
  static Color levelColor(String level) {
    const ladder = [
      Color(0xFF16A34A), // A1 / HSK1
      Color(0xFF0D9488), // A2 / HSK2
      Color(0xFF2563EB), // B1 / HSK3
      Color(0xFF4F46E5), // B2 / HSK4
      Color(0xFF7C3AED), // C1 / HSK5
      Color(0xFFC026D3), // C2 / HSK6
    ];
    final normalized = level.trim().toUpperCase();
    const cefr = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    var index = cefr.indexOf(normalized);
    if (index < 0) {
      final hsk = RegExp(r'(\d)').firstMatch(normalized);
      index = hsk == null ? 2 : (int.parse(hsk.group(1)!) - 1).clamp(0, 5);
    }
    return ladder[index];
  }

  /// Shared look: flat tonal cards, generous touch targets (48dp), rounded
  /// inputs and buttons, and a clear title weight.
  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme;
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
      textTheme: text.copyWith(
        displaySmall: text.displaySmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineSmall:
            text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      // Soft depth: a low, brand-tinted shadow instead of flat tonal cards.
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: scheme.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        color: scheme.surfaceContainerLowest,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.surface),
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
        style: OutlinedButton.styleFrom(
            minimumSize: minButton, shape: buttonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        minVerticalPadding: 12,
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    );
  }
}
