import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:sk_core/testing/fakes.dart';
import 'package:color_beats/main.dart';
import 'package:color_beats_game/color_beats/board/block_board_view.dart';
import 'package:color_beats_game/color_beats/engine/levels.dart';

void main() {
  testWidgets('standalone Color Beats: home -> goal -> board -> drag a piece', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        speechProvider.overrideWithValue(FakeSpeech()),
        audioProvider.overrideWithValue(FakeAudio()),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const ColorBeatsApp()),
    );
    await tester.pump();

    expect(find.text('Color Beats'), findsWidgets);
    expect(find.text('Snack Beats'), findsNothing);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(levelSentence(blockLevel(0), Lang.en)), findsOneWidget);

    await tester.tap(find.text("Let's go!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BlockBoardView), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(c.read(eventLogProvider).ofType('level_start'), hasLength(1));

    // Drag the first tray piece up onto the board: blocks land, score goes up.
    final board = tester.getRect(find.byType(BlockBoardView));
    final side = board.width < board.height / 1.48
        ? board.width
        : (board.height / 1.48).floorToDouble();
    final top = ((board.height - side * 1.48) / 3).floorToDouble();
    final cell = side / 8;
    final slot0 = Offset(
      board.left + board.width / 6,
      board.top + top + side + cell * 0.45 + cell * 1.7,
    );
    final g = await tester.startGesture(slot0);
    for (var i = 1; i <= 10; i++) {
      await g.moveBy(Offset(0, -side * 0.05));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0'), findsNothing); // score is no longer 0

    await tester.tap(find.text('⌂'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 25));
    c.dispose();
  });
}
