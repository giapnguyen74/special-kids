import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sing_say/main.dart';
import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/speech/speech_service.dart';
import 'package:sk_core/testing/fakes.dart';

void main() {
  testWidgets('Sing & Say app: home -> song picker -> home', (tester) async {
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
      UncontrolledProviderScope(container: c, child: const SingSayApp()),
    );
    await tester.pump();
    expect(find.text('Sing & Say'), findsWidgets);
    expect(find.text('Snack Beats'), findsNothing);
    expect(find.text('Color Beats'), findsNothing);

    await tester.tap(find.text("Let's sing!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Choose a song'), findsOneWidget);
    expect(c.read(eventLogProvider).ofType('start'), hasLength(1));

    await tester.tap(find.text('⌂'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text("Let's sing!"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    c.dispose();
  });
}
