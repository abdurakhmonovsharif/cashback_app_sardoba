import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/components/points_balance_card.dart';

void main() {
  Future<void> showCard(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    String balanceLabel = '10 642,5',
    String? balanceUnit = 'балл',
    String helper = 'Доступно после 30 000 баллов',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PointsBalanceCard(
                  title: 'Количество баллов',
                  balanceLabel: balanceLabel,
                  balanceUnit: balanceUnit,
                  helper: helper,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('balance, unit, and supporting text use the intended hierarchy',
      (tester) async {
    await showCard(tester, size: const Size(375, 812), textScale: 1);

    final title = tester.widget<Text>(find.text('Количество баллов'));
    final balance = tester.widget<Text>(find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.textSpan?.toPlainText() == '10 642,5 балл',
    ));
    final unit = (balance.textSpan as TextSpan).children!.single as TextSpan;
    final helper =
        tester.widget<Text>(find.text('Доступно после 30 000 баллов'));

    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(balance.style?.fontSize, 28);
    expect(balance.style?.fontWeight, FontWeight.w700);
    expect(unit.style?.fontSize, 16);
    expect(unit.style?.fontWeight, FontWeight.w500);
    expect(helper.style?.fontSize, 14);
    expect(helper.style?.height, 1.4);
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(264, 700), scale: 1.0),
    (size: const Size(440, 900), scale: 1.0),
    (size: const Size(600, 900), scale: 1.0),
    (size: const Size(840, 1000), scale: 1.0),
    (size: const Size(1024, 900), scale: 1.0),
    (size: const Size(375, 812), scale: 2.0),
    (size: const Size(320, 568), scale: 3.0),
    (size: const Size(812, 375), scale: 2.0),
  ]) {
    testWidgets('card wraps at ${scenario.size} and ${scenario.scale}x text',
        (tester) async {
      await showCard(
        tester,
        size: scenario.size,
        textScale: scenario.scale,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PointsBalanceCard)).height,
          greaterThanOrEqualTo(104));
    });
  }

  testWidgets('long balance remains readable without a layout overflow',
      (tester) async {
    await showCard(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      balanceLabel: '1 234 567 890,5',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('missing balance has no unit', (tester) async {
    await showCard(
      tester,
      size: const Size(375, 812),
      textScale: 1,
      balanceLabel: '—',
      balanceUnit: null,
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('балл'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest state stays compact at standard text size',
      (tester) async {
    await showCard(
      tester,
      size: const Size(390, 844),
      textScale: 1,
      balanceLabel: '—',
      balanceUnit: null,
      helper: 'Авторизуйтесь, чтобы увидеть баллы.',
    );

    expect(tester.getSize(find.byType(PointsBalanceCard)).height,
        inInclusiveRange(112, 144));
  });
}
