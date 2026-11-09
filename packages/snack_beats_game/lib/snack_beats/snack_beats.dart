import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_core/core/skills/skills.dart';

import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/break_screen.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/ui/routes.dart';

import 'screens/intro_screen.dart';
import 'screens/play_screen.dart';

/// Entry points for the Snack Beats game module.
abstract final class SnackBeats {
  static const id = 'snack_beats';

  /// Where skill lessons can appear in Snack Beats, which lessons fit, and the defaults.
  static const skillSpec = GameSkillSpec(
    id: id,
    emoji: '🍓',
    titleEn: 'Snack Beats',
    titleVi: 'Snack Beats',
    slots: {
      SkillSlot.afterLevel: ['ask_treat', 'ask_help', 'counting'],
      SkillSlot.outOfMoves: ['ask_help', 'counting'],
    },
    defaults: {
      SkillSlot.afterLevel: ['ask_treat'],
      SkillSlot.outOfMoves: ['ask_help', 'counting'],
    },
  );

  /// QA builds: --dart-define=SK_LEVEL=n starts at level n.
  static const _qaLevel = int.fromEnvironment('SK_LEVEL');

  static int currentLevel(WidgetRef ref) => _qaLevel > 0
      ? _qaLevel - 1
      : (ref.read(profileProvider).gameLevels[id] ?? 0);

  /// Start (or continue) at the child's current level. Shows the break screen if the session limit is reached.
  static void start(
    BuildContext context,
    WidgetRef ref, {
    bool replace = false,
  }) {
    final Widget page = ref.read(sessionProvider).breakDue
        ? BreakScreen(onContinue: (ctx, r) => start(ctx, r, replace: true))
        : IntroScreen(levelIndex: currentLevel(ref));
    final nav = Navigator.of(context);
    replace ? nav.pushReplacement(fadeRoute(page)) : nav.push(fadeRoute(page));
  }

  static void startCalm(BuildContext context) =>
      Navigator.of(context).push(fadeRoute(const PlayScreen.calm()));
}
