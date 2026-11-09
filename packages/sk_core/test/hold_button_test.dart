import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sk_core/core/ui/palette.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';

void main() {
  testWidgets('quick tap shows the hint; holding shows progress and opens', (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(body: Center(child: HoldButton(label: 'Phụ huynh', onComplete: () => opened++))),
    ));

    // Quick tap: nothing opens, the hint appears.
    await tester.tap(find.text('Phụ huynh'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, 0);
    expect(find.text('Nhấn giữ để mở'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // Hold: the blue fill is visible while holding, then it opens.
    final g = await tester.startGesture(tester.getCenter(find.text('Phụ huynh')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final fill = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, greaterThan(0.3));
    final stack = tester.widget<Stack>(find.descendant(of: find.byType(HoldButton), matching: find.byType(Stack)).first);
    expect(stack.children.last, isA<Positioned>(), reason: 'fill must be drawn on top');
    expect(((fill.child! as ColoredBox).color).toARGB32() & 0xFFFFFF, Pure.blue.toARGB32() & 0xFFFFFF);
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await tester.pump();
    expect(opened, 1);
    await tester.pump(const Duration(seconds: 3));
  });
}
