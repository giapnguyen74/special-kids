import 'package:flutter/material.dart';

import 'effects.dart';

/// Bright, cheerful, high-contrast palette: light sky background, dark navy text,
/// white surfaces and standard saturated accents (see [Pure]). Not babyish.
abstract final class AppColors {
  static const bg1 = Color(0xFF4FC3F7); // sky blue
  static const bg2 = Color(0xFF81D4FA); // light sky
  static const bg3 = Color(0xFFE1F5FE); // almost white
  static const text = Color(0xFF0D1B5E); // dark navy (main text)
  static const muted = Color(0xFF3F51A5); // secondary text
  static const accent = Color(0xFFFFD600);
  static const accentShadow = Color(0xFFC7A500);
  static const accentInk = Color(0xFF3A2A00);
  static const ink = Color(0xFF1A2250);
  // Surfaces (pills, chips, secondary buttons): solid white so they stand out on the sky.
  static const glass = Color(0xF2FFFFFF);
  static const glass2 = Color(0xFFFFFFFF);
  static const shadow = Color(
    0x332962FF,
  ); // soft blue shadow under white surfaces
  static const mint = Color(0xFF00E676);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFEEF1FF);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2979FF),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bg1,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}

/// Shared screen background for every game and tool.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.colors});
  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors ?? const [AppColors.bg1, AppColors.bg2, AppColors.bg3],
        ),
      ),
      child: Stack(
        fit: StackFit.expand, // fill the screen even when the content is short
        children: [
          const Positioned.fill(child: FloatingBubbles()),
          child,
        ],
      ),
    );
  }
}

class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.child,
    this.colors,
    this.scroll = false,
  });
  final Widget child;
  final List<Color>? colors;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child,
    );
    return Scaffold(
      body: AppBackground(
        colors: colors,
        child: SafeArea(
          child: scroll ? SingleChildScrollView(child: body) : body,
        ),
      ),
    );
  }
}
