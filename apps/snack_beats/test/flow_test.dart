import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:snack_beats_game/snack_beats/levels.dart';
import 'package:sk_core/core/lessons/treat_lesson_screen.dart';
import 'package:sk_core/core/skills/skills.dart';
import 'package:sk_core/l10n/app_localizations.dart';
import 'package:sk_core/testing/fakes.dart';
import 'package:snack_beats/main.dart';

Future<ProviderContainer> _scope(
  WidgetTester tester,
  Widget child, {
  FakeSpeech? speech,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      speechProvider.overrideWithValue(speech ?? FakeSpeech()),
      audioProvider.overrideWithValue(FakeAudio()),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: child),
  );
  return container;
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// One frame to process the tap/navigation, then advance time.
Future<void> settle(WidgetTester tester, int ms) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Finder wordTile(String word) => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key as ValueKey).value}'.endsWith('-$word'),
    )
    .first;

void main() {
  testWidgets('skill lesson "ask_treat": choose food, build sentence, say it', (
    tester,
  ) async {
    final speech = FakeSpeech();
    final lv = snackLevel(0);
    final outcomes = <SkillOutcome?>[];
    final c = await _scope(
      tester,
      _app(
        Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () async => outcomes.add(
                await Navigator.of(ctx).push<SkillOutcome>(
                  MaterialPageRoute(
                    builder: (_) => TreatLessonScreen(
                      request: SkillRequest(
                        game: 'snack_beats',
                        slot: SkillSlot.afterLevel,
                        levelIndex: 0,
                        suggestedFood: lv.goals.first.food,
                        customer: lv.customer,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      speech: speech,
    );
    await tester.tap(find.text('open'));
    await settle(tester, 400);
    expect(
      find.text('Thank you! Now you pick a treat. What do you want?'),
      findsOneWidget,
    );

    await tester.tap(find.text('🍌')); // level 1 goal fruit
    await settle(tester, 600);
    expect(find.text('Make the sentence'), findsOneWidget);

    // Wrong tile first (counts as a mistake), then the correct order.
    await tester.tap(wordTile('want'));
    await settle(tester, 400);
    for (final w in ['I', 'want', 'a banana']) {
      await tester.tap(wordTile(w));
      await settle(tester, 100);
    }
    expect(find.text('I want a banana.'), findsOneWidget);
    expect(speech.said, contains('I want a banana.'));

    await tester.tap(find.text('I said it! 🎤'));
    await settle(tester, 3000);
    expect(outcomes.single!.module, 'ask_treat');
    expect(outcomes.single!.spoke, isTrue);

    final p = c.read(profileProvider);
    expect(p.stars, 3);
    final ev = c.read(eventLogProvider).ofType('sentence').single;
    expect(ev.get<int>('words'), 4);
    expect(ev.get<int>('wrong'), 1);
    expect(ev.get<bool>('spoke'), isTrue);
    // A mistake was made, so help stays at full model (level 0).
    expect(p.hintFor(Lang.en), 0);

    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('home -> intro -> board, with self-start reward', (tester) async {
    final c = await _scope(tester, const SnackBeatsApp());
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(
      find.text('Play'),
    ); // immediately = before the cue -> self-start
    await settle(tester, 600);
    expect(find.text(levelSentence(snackLevel(0), Lang.en)), findsOneWidget);
    expect(c.read(profileProvider).stars, 1);
    expect(c.read(profileProvider).cueDelayMs, 4000);

    await tester.tap(find.text("Let's go!"));
    await settle(tester, 600);
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('${snackLevel(0).moves}'), findsOneWidget);

    final starts = c.read(eventLogProvider).ofType('start').toList();
    expect(starts.map((e) => e.get<String>('context')), ['hub', 'level']);
    expect(starts.every((e) => e.get<bool>('selfStart') == true), isTrue);

    // Leave so timers and the game are disposed cleanly.
    await tester.tap(find.text('⌂'));
    await settle(tester, 3000);
    expect(find.text('Play'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    c.dispose();
  });
}
