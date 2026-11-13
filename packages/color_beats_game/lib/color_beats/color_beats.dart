import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/break_screen.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/skills/skills.dart';
import 'package:sk_core/core/ui/routes.dart';

import 'screens/intro_screen.dart';
import 'screens/play_screen.dart';

/// Entry points for the Color Beats block puzzle: place 1 of 3 pieces on an 8x8 board,
/// full rows/columns clear and play the notes of a song. When no piece fits, a short
/// skill challenge (chosen by the parent) clears space so the child can keep playing.
abstract final class ColorBeats {
  static const id = 'color_beats';

  static const skillSpec = GameSkillSpec(
    id: id,
    emoji: '🧱',
    titleEn: 'Color Beats',
    titleVi: 'Color Beats',
    slots: {
      SkillSlot.afterLevel: ['ask_treat', 'ask_help', 'counting'],
      SkillSlot.outOfMoves: ['ask_help', 'counting'],
    },
    defaults: {
      SkillSlot.afterLevel: ['counting'],
      SkillSlot.outOfMoves: ['ask_help', 'counting'],
    },
    slotTitles: {
      SkillSlot.outOfMoves: (
        'When no block fits (a challenge clears space)',
        'Khi hết chỗ xếp gạch (làm thử thách để có thêm chỗ)',
      ),
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
        : BlockIntroScreen(levelIndex: currentLevel(ref));
    final nav = Navigator.of(context);
    replace ? nav.pushReplacement(fadeRoute(page)) : nav.push(fadeRoute(page));
  }

  /// Endless relaxed play: no goals, and a full board simply makes space by itself.
  static void startCalm(BuildContext context) =>
      Navigator.of(context).push(fadeRoute(const BlockPlayScreen.calm()));
}
