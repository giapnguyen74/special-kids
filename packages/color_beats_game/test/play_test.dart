import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/lessons/bonus_lesson_screen.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/skills/skills.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:sk_core/l10n/app_localizations.dart';
import 'package:sk_core/testing/fakes.dart';
import 'package:color_beats_game/color_beats/board/block_game.dart';
import 'package:color_beats_game/color_beats/engine/grid.dart';
import 'package:color_beats_game/color_beats/engine/level_gen.dart';
import 'package:color_beats_game/color_beats/engine/levels.dart';
import 'package:color_beats_game/color_beats/screens/play_screen.dart';
import 'package:color_beats_game/color_beats/color_beats.dart';

/// A level whose board is completely full: nothing fits from the start.
BlockLevel fullLevel() => BlockLevel(
  index: 0,
  data: LevelData(
    tier: 0,
    lines: 3,
    score: 0,
    board: List.filled(8, '11111111'),
  ),
);

void main() {
  testWidgets(
    'stuck board reports once; rescue makes space and a fitting tray',
    (tester) async {
      var stuck = 0;
      final game = BlockGame(
        grid: fullLevel().newGrid(),
        dealer: PieceDealer(tier: 1, rng: Random(1)),
        onStuck: () => stuck++,
      );
      expect(game.locked, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(stuck, 1);
      final r = game.rescue();
      expect(r.rows, hasLength(3));
      expect(game.locked, isFalse);
      expect(game.tray.any((p) => p != null && game.grid.fits(p)), isTrue);
      game.dispose();
    },
  );

  testWidgets('full board: card offers the challenge, which opens the lesson', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        speechProvider.overrideWithValue(FakeSpeech()),
        audioProvider.overrideWithValue(FakeAudio()),
        gameSkillSpecsProvider.overrideWithValue(const [ColorBeats.skillSpec]),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlockPlayScreen(level: fullLevel()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No more space!'), findsOneWidget);
    expect(find.text('🎁 New blocks'), findsOneWidget);
    expect(
      c.read(eventLogProvider).ofType('level').single.data['result'],
      'retry',
    );

    await tester.tap(find.text('🎁 New blocks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final lesson = tester.widget<BonusLessonScreen>(
      find.byType(BonusLessonScreen),
    );
    expect(lesson.rewardKind, SkillReward.blocks);

    // Finish the lesson (as the lesson does) -> back on the board with space to play.
    Navigator.of(tester.element(find.byType(BonusLessonScreen)))
        .pop(const SkillOutcome('ask_help'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No more space!'), findsNothing);
    expect(c.read(eventLogProvider).ofType('extra_moves'), hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    c.dispose();
  });
}
