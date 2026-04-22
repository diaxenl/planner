import 'package:flutter/material.dart';

/// Centralized design tokens for HyperDay.
///
/// All colors, text styles, and theme data are defined here.
/// Nothing visual is hardcoded in widgets.
class AppTheme {
  AppTheme._();

  // ── Colors ──────────────────────────────────────────────────────────
  static const Color seedColor = Color(0xFF3B82F6); // blue-500
  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color timelineDividerColor = Color(0xFFE5E7EB); // gray-200
  static const Color hourLabelColor = Color(0xFF9CA3AF); // gray-400
  static const Color emptyStateColor = Color(0xFF6B7280); // gray-500

  /// The app-wide [ThemeData] applied to [MaterialApp].
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: surfaceColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),
      textTheme: const TextTheme(
        // Day header date text
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        // Hour labels on the timeline
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: hourLabelColor,
        ),
        // Empty state message
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: emptyStateColor,
        ),
      ),
    );
  }
}
