import 'package:flutter/material.dart';

/// Centralized design tokens for HyperDay.
///
/// Calm, typographic, dark by default. Neutrals do the work; exactly one
/// accent color, reserved for "now", Outcomes, and overrun warnings.
/// Nothing visual is hardcoded in widgets — read [HyperColors] via
/// `HyperColors.of(context)` and text styles via the [TextTheme].
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Inter';

  /// Tabular figures keep times and timers from jittering as digits change.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const HyperColors _dark = HyperColors(
    background: Color(0xFF0E0F11),
    surface: Color(0xFF17191C),
    hairline: Color(0xFF2A2D32),
    textPrimary: Color(0xFFEDEEF0),
    textSecondary: Color(0xFF9A9FA6),
    textMuted: Color(0xFF61666D),
    accent: Color(0xFFF2B544),
    onAccent: Color(0xFF1A1405),
    meeting: Color(0xFF4A4F57),
    other: Color(0xFF8A9099),
  );

  static const HyperColors _light = HyperColors(
    background: Color(0xFFF7F6F3),
    surface: Color(0xFFFFFFFF),
    hairline: Color(0xFFE4E2DD),
    textPrimary: Color(0xFF141517),
    textSecondary: Color(0xFF5F646B),
    textMuted: Color(0xFF9A9EA4),
    accent: Color(0xFFC98512),
    onAccent: Color(0xFFFFFFFF),
    meeting: Color(0xFFA2A7AF),
    other: Color(0xFF5F656E),
  );

  static ThemeData get darkTheme => _build(_dark, Brightness.dark);
  static ThemeData get lightTheme => _build(_light, Brightness.light);

  static ThemeData _build(HyperColors c, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.textSecondary,
      onSecondary: c.background,
      error: const Color(0xFFE5484D),
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.hairline,
      outline: c.hairline,
      outlineVariant: c.hairline,
    );

    // Apply Inter to every role, including ones used by buttons.
    final text = _textTheme(c).apply(fontFamily: fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      extensions: [c],
      splashFactory: NoSplash.splashFactory,
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: c.textMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(0, 48),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.hairline),
          minimumSize: const Size(0, 48),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textSecondary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.background,
        hintStyle: text.bodyLarge?.copyWith(color: c.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.textSecondary),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: c.textSecondary,
          selectedForegroundColor: c.textPrimary,
          selectedBackgroundColor: c.hairline,
          side: BorderSide(color: c.hairline),
          textStyle: text.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.hairline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  static TextTheme _textTheme(HyperColors c) => TextTheme(
        // Live timer on the Now card.
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -2,
          height: 1.0,
          color: c.textPrimary,
          fontFeatures: tabularFigures,
        ),
        // Big stats (e.g. outcomes hit in Review).
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: c.textPrimary,
          fontFeatures: tabularFigures,
        ),
        // Date header.
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: c.textPrimary,
        ),
        // Now-card title, sheet titles.
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: c.textPrimary,
        ),
        // Outcome rows, app bar titles.
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        // Agenda rows.
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: c.textSecondary,
        ),
        // Times and durations in rows.
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.textSecondary,
          fontFeatures: tabularFigures,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        // Section headers ("OUTCOMES", "LATER TODAY").
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: c.textMuted,
        ),
      );
}

/// HyperDay's color tokens, attached to [ThemeData.extensions].
class HyperColors extends ThemeExtension<HyperColors> {
  const HyperColors({
    required this.background,
    required this.surface,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.meeting,
    required this.other,
  });

  final Color background;
  final Color surface;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// The single accent: now, Outcomes, overrun.
  final Color accent;
  final Color onAccent;

  /// Load-bar segment colors (Outcomes use [accent], Free uses [hairline]).
  final Color meeting;
  final Color other;

  static HyperColors of(BuildContext context) =>
      Theme.of(context).extension<HyperColors>()!;

  @override
  HyperColors copyWith({
    Color? background,
    Color? surface,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? meeting,
    Color? other,
  }) =>
      HyperColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        hairline: hairline ?? this.hairline,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        meeting: meeting ?? this.meeting,
        other: other ?? this.other,
      );

  @override
  HyperColors lerp(HyperColors? other, double t) {
    if (other == null) return this;
    return HyperColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      meeting: Color.lerp(meeting, other.meeting, t)!,
      other: Color.lerp(this.other, other.other, t)!,
    );
  }
}
