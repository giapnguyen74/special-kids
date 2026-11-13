import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/session/break_screen.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/ui/routes.dart';

import 'screens/song_picker_screen.dart';

/// Entry point for the Sing & Say game module.
abstract final class SingSay {
  static const id = 'sing_say';

  static void start(
    BuildContext context,
    WidgetRef ref, {
    bool replace = false,
  }) {
    final Widget page = ref.read(sessionProvider).breakDue
        ? BreakScreen(onContinue: (ctx, r) => start(ctx, r, replace: true))
        : const SongPickerScreen();
    final nav = Navigator.of(context);
    replace ? nav.pushReplacement(fadeRoute(page)) : nav.push(fadeRoute(page));
  }
}
