import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sk_core/core/sentence/sentence_builder.dart';

Finder tile(String w) => find
    .byWidgetPredicate(
      (x) =>
          x.key is ValueKey && '${(x.key as ValueKey).value}'.endsWith('-$w'),
    )
    .first;

void main() {
  testWidgets(
    'errorless: 3 wrong taps -> the app places the right word; sentence always finishes',
    (tester) async {
      SentenceResult? result;
      final placed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SentenceBuilder(
              words: const ['I', 'want', 'a banana'],
              distractor: 'go',
              hintLevel: 2,
              onWordPlaced: (w, _) => placed.add(w),
              onDone: (r) => result = r,
            ),
          ),
        ),
      );
      // Child keeps tapping the wrong word for the first slot.
      for (var i = 0; i < 3; i++) {
        await tester.tap(tile('go'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(placed, ['I']); // the app put "I" in for the child

      await tester.tap(tile('want'));
      await tester.pump();
      await tester.tap(tile('a banana'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(result, isNotNull);
      expect(result!.wrong, 3);
      expect(result!.hints, greaterThanOrEqualTo(2)); // glow + auto-place
    },
  );

  testWidgets('one wrong tap makes the right word glow right away', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SentenceBuilder(
            words: const ['Can', 'I', 'have'],
            distractor: 'no',
            hintLevel: 2,
            onDone: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(tile('no'));
    await tester.pump(const Duration(milliseconds: 400));
    // The glowing tile has a yellow glow shadow.
    final glowing = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) {
          final d = c.decoration;
          return d is BoxDecoration && (d.boxShadow?.length ?? 0) > 1;
        });
    expect(glowing, hasLength(1));
    await tester.pump(const Duration(seconds: 10));
  });
}
