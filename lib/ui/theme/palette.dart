import 'package:flutter/material.dart';

/// Light "paper & ink" theme for the whole UI (design direction: warm
/// off-white background, warm dark text that never goes pure black, golden
/// accents). Every widget should pull colors from here instead of hardcoding.
abstract final class Palette {
  // ---------------------------------------------------------- surfaces
  /// App/board background — slightly yellow paper.
  static const Color paper = Color(0xFFF6F1E7);
  /// Cards and panels, a shade lighter than the paper.
  static const Color surface = Color(0xFFFFFBF3);
  /// Secondary surfaces: banners, headers, disabled fills.
  static const Color surfaceAlt = Color(0xFFEFE7D6);
  /// Card borders and dividers.
  static const Color border = Color(0xFFD9CFBA);
  /// Faint grid drawn on the board behind the overlay.
  static const Color gridLine = Color(0xFFEAE0CA);
  /// Soft dimming scrim behind modal panels.
  static const Color scrim = Color(0x592E2A23);

  // ---------------------------------------------------------------- ink
  /// Primary text — warm near-black, never #000.
  static const Color ink = Color(0xFF2E2A23);
  /// Secondary text.
  static const Color inkSoft = Color(0xFF6E675A);
  /// Tertiary/disabled text (kept dark enough for 12px legibility).
  static const Color inkFaint = Color(0xFF746B5A);

  // ------------------------------------------------------------ accents
  /// Deep goldenrod for highlights, trends, section titles.
  static const Color accent = Color(0xFF8A6512);
  /// Deep sepia for action buttons; reads as pressed ink on paper.
  static const Color action = Color(0xFF5A4632);
  /// Amber for warnings and locked items.
  static const Color warn = Color(0xFFB07D2A);
  /// Rust red for retractions, burnout and other hazards.
  static const Color danger = Color(0xFFB4543A);
}
