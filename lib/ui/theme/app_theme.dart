import 'package:flutter/material.dart';

import 'palette.dart';

/// Material-level theming that matches the paper-and-ink UI. Widgets that
/// rely on inherited theming (dialogs, text fields, scrollbars, buttons)
/// pick up paper/ink/gold colours here instead of platform defaults.
abstract final class AppTheme {
  static ThemeData get data {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Palette.action,
      onPrimary: Palette.onFill,
      secondary: Palette.accent,
      onSecondary: Palette.onFill,
      error: Palette.danger,
      onError: Palette.onFill,
      surface: Palette.paper,
      onSurface: Palette.ink,
      surfaceContainerHighest: Palette.surfaceAlt,
      onSurfaceVariant: Palette.inkSoft,
      outline: Palette.border,
      outlineVariant: Palette.gridLine,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.paper,
      dialogTheme: DialogThemeData(
        backgroundColor: Palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.surface,
        hintStyle: TextStyle(color: Palette.inkFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: Palette.border),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Palette.border),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
