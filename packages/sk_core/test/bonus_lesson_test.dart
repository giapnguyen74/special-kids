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

/// Opens the lesson from a launcher screen and returns the container + a result holder.
Future<(ProviderContainer, List<SkillOutcome?>)> open(
  WidgetTester tester,
  BonusTask task,
  int seed,
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
  final results = <SkillOutcome?>[];
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => results.add(
                  await Navigator.of(ctx).push<SkillOutcome>(
                    MaterialPageRoute(
                      builder: (_) => BonusLessonScreen(
                        task: task,
                        seed: seed,
                        game: 'test',
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 3));
  return (c, results);
}

void main() {
  testWidgets(
    'count task: a wrong number makes the right one glow, right answer finishes',
    (tester) async {
      final (c, results) = await open(tester, BonusTask.count, 3);
      final prompt = find.textContaining('How many');
      expect(prompt, findsWidgets);
      // Count the fruit emojis shown (the big ones in the white card).
      final n = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.style?.fontSize ?? 0) == 48)
          .length;
      final numbers = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.style?.fontSize ?? 0) == 44)
          .map((t) => int.parse(t.data!))
          .toList();
      expect(numbers, contains(n));
      final wrong = numbers.firstWhere((x) => x != n);
      await tester.tap(find.text('$wrong'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('$n'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(results.single!.module, 'counting');
      expect(results.single!.wrong, 1);
      final ev = c.read(eventLogProvider).ofType('count').single;
      expect(ev.get<int>('n'), n);
      expect(c.read(profileProvider).stars, 1);
      c.dispose();
    },
  );

  testWidgets(
    'request task: build "Can I have more moves please", say it -> result + sentence logged',
    (tester) async {
      final (c, results) = await open(tester, BonusTask.request, 0);
      for (final w in ['Can', 'I', 'have', 'more', 'moves', 'please']) {
        final tile = find
            .byWidgetPredicate(
              (x) =>
                  x.key is ValueKey &&
                  '${(x.key as ValueKey).value}'.endsWith('-$w'),
            )
            .first;
        await tester.ensureVisible(tile);
        await tester.pump();
        await tester.tap(tile);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Can I have more moves please?'), findsOneWidget);
      await tester.ensureVisible(find.text('I said it! 🎤'));
      await tester.pump();
      await tester.tap(find.text('I said it! 🎤'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(results.single!.spoke, isTrue);
      final sent = c.read(eventLogProvider).ofType('sentence').single;
      expect(sent.get<String>('source'), 'bonus');
      expect(c.read(profileProvider).stars, 2);
      c.dispose();
    },
  );
}
