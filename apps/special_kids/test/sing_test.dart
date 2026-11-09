import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:special_kids/voice/voice_meter.dart';
import 'package:special_kids/games/sing_say/screens/sing_screen.dart';
import 'package:special_kids/games/sing_say/sing_songs.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import 'fakes.dart';

Future<ProviderContainer> _start(WidgetTester tester, FakeVoice voice) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      speechProvider.overrideWithValue(FakeSpeech()),
      audioProvider.overrideWithValue(FakeAudio()),
      voiceProvider.overrideWithValue(voice),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SingScreen(song: singSongs[0]),
      ),
    ),
  );
  return c;
}

Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _until(WidgetTester tester, Finder f, {int maxMs = 120000}) async {
  for (var t = 0; t < maxMs; t += 100) {
    if (f.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (f.evaluate().isEmpty) {
    debugPrint(
      'DBG texts: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText()).toList()}',
    );
  }
  return f.evaluate().isNotEmpty;
}

void main() {
  testWidgets(
    'with mic: singing loudly lights every line, sentences are heard',
    (tester) async {
      final voice = FakeVoice();
      final c = await _start(tester, voice);
      await _advance(tester, 1500); // mic starts + quiet-room calibration

      await tester.tap(find.text("Let's sing!"));
      await _advance(
        tester,
        2200,
      ); // count-in (still quiet: measures our own music level)
      voice.level = 0.85; // child sings / talks loudly from now on

      expect(
        await _until(tester, find.text('You sang the whole song!')),
        isTrue,
      );
      expect(find.text('6 of 6 lines with your voice'), findsOneWidget);

      final ev = c.read(eventLogProvider).ofType('sing_song').single;
      expect(ev.get<int>('voiced'), 6);
      expect(ev.get<int>('sayVoiced'), 2);
      expect(ev.get<bool>('mic'), isTrue);
      // 6 lines x1 + 2 sentences x2 + 1 self-start bonus
      expect(c.read(profileProvider).stars, 11);
      // Sang every line -> less help next time.
      expect(c.read(profileProvider).hintLevel['sing_en'], 1);

      await tester.pumpWidget(const SizedBox());
      await _advance(tester, 3000);
      c.dispose();
    },
  );

  testWidgets('without mic: buttons are offered, nothing is forced', (
    tester,
  ) async {
    final c = await _start(tester, FakeVoice(available: false));
    await _advance(tester, 500);
    expect(find.text("Mic is off — that's okay! Just sing."), findsOneWidget);

    await tester.tap(find.text("Let's sing!"));
    for (var k = 0; k < 2; k++) {
      expect(await _until(tester, find.text('I said it! 🎤')), isTrue);
      await tester.tap(find.text('I said it! 🎤'));
      await _advance(tester, 200);
      expect(
        find.text('I said it! 🎤'),
        findsNothing,
      ); // buttons hide right away
    }
    expect(await _until(tester, find.text('Did you sing along?')), isTrue);
    await tester.tap(find.text('I sang! 🎤'));
    await _advance(tester, 500);

    final events = c.read(eventLogProvider).ofType('sing_song').toList();
    expect(events, hasLength(1));
    expect(events.single.get<bool>('selfReportSang'), isTrue);
    expect(events.single.get<bool>('mic'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await _advance(tester, 3000);
    c.dispose();
  });
}
