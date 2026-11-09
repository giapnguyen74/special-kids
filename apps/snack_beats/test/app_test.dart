import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:snack_beats_game/snack_beats/levels.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:sk_core/testing/fakes.dart';
import 'package:snack_beats/main.dart';

void main() {
  testWidgets('standalone Snack Beats: home -> order -> board', (tester) async {
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
      UncontrolledProviderScope(container: c, child: const SnackBeatsApp()),
    );
    await tester.pump();

    expect(find.text('Snack Beats'), findsWidgets); // outlined title = 2 layers
    expect(find.text('Sing & Say'), findsNothing); // standalone: only this game

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(levelSentence(snackLevel(0), Lang.en)), findsOneWidget);

    await tester.tap(find.text("Let's go!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Moves'), findsOneWidget);
    expect(c.read(eventLogProvider).ofType('start'), hasLength(2));

    // Restart: asks first; "Keep playing" does nothing, "Restart" starts the level over.
    await tester.tap(find.text('↻'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start this level again?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start this level again?'), findsNothing);
    expect(c.read(eventLogProvider).ofType('restart'), isEmpty);

    await tester.tap(find.text('↻'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Restart ↻'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('${snackLevel(0).moves}'), findsOneWidget);
    expect(c.read(eventLogProvider).ofType('restart'), hasLength(1));

    await tester.tap(find.text('⌂'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    c.dispose();
  });
}
