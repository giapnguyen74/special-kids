import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/initiation/start_cue_button.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import '../levels.dart';
import '../snack_beats.dart';
import 'goal_chips.dart';
import 'play_screen.dart';

/// A customer places an order (spoken). The child starts the level themself.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key, required this.levelIndex});
  final int levelIndex;
  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> with TracksPlayTime {
  late final SnackLevel level = snackLevel(widget.levelIndex);

  String get _sentence => levelSentence(level, ref.read(profileProvider).lang);

  void _speak() =>
      ref.read(speechProvider).speak(_sentence, ref.read(profileProvider).lang);

  @override
  void initState() {
    super.initState();
    startTracking(ref.read(sessionProvider));
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _speak();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(profileProvider.select((p) => p.lang));
    return AppScreen(
      child: Column(
        children: [
          Row(
            children: [
              HomeBtn(onBeforeLeave: () => ref.read(speechProvider).stop()),
              const Spacer(),
              Pill(
                child: Text(
                  l.levelN(level.index + 1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              const StarsPill(),
            ],
          ),
          const SizedBox(height: 16),
          Bob(
            child: Text(level.customer, style: const TextStyle(fontSize: 110)),
          ),
          const SizedBox(height: 16),
          SpeechBubble(text: _sentence, onSpeak: _speak),
          const SizedBox(height: 18),
          GoalChips(items: goalItems(level)),
          const SizedBox(height: 28),
          StartCueButton(
            label: l.start,
            cueContext: 'level',
            game: SnackBeats.id,
            onStart: () {
              ref.read(speechProvider).stop();
              Navigator.of(context)
                  .pushReplacement(fadeRoute(PlayScreen(level: level)));
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Small helper so other screens can show the customer consistently.
Widget customerFace(String emoji, {double size = 56}) => Text(
  emoji,
  style: TextStyle(fontSize: size, color: AppColors.text),
);
