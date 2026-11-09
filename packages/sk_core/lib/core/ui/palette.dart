import 'dart:ui';

/// Standard, fully saturated colors (candy-style) — easy to tell apart at a glance.
/// Use these everywhere instead of in-between shades.
abstract final class Pure {
  static const red = Color(0xFFFF1744);
  static const orange = Color(0xFFFF6D00);
  static const yellow = Color(0xFFFFD600);
  static const green = Color(0xFF00C853);
  static const blue = Color(0xFF2979FF);
  static const purple = Color(0xFFAA00FF);

  /// For rainbow rings, rays, confetti.
  static const rainbow = [red, orange, yellow, green, blue, purple, red];
}
