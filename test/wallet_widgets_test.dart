import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/screens/points/points_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/constants.dart';
import 'package:sardoba_app/screens/points/wallet_widgets.dart';
import 'package:sardoba_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('SF Pro Text');
    for (final weight in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      loader.addFont(
          rootBundle.load('assets/font/SF Pro Text/SFProText-$weight.ttf'));
    }
    await loader.load();
  });

  Widget balance(
          {bool eligible = false,
          VoidCallback? onView,
          String value = '10 643'}) =>
      WalletBalanceCard(
          title: 'Количество баллов',
          balanceLabel: value,
          unit: 'балл',
          helper: '',
          progress: eligible ? 1 : 10643 / 30000,
          thresholdLabel: 'Использование баллов доступно от 30 000 балл',
          remainingLabel: 'До использования осталось 19 357 балл',
          canView: eligible,
          onView: onView ?? () {},
          ctaLabel: 'Посмотреть');

  Future<void> show(WidgetTester tester, Widget child,
      {double width = 390,
      double scale = 1,
      TargetPlatform platform = TargetPlatform.iOS}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildThemeData().copyWith(platform: platform),
      home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 1100), textScaler: TextScaler.linear(scale)),
          child: Scaffold(
              backgroundColor: screenBackgroundColor,
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16), child: child))),
    ));
    await tester.pump();
  }

  for (final locale in [AppLocale.ru, AppLocale.uz]) {
    testWidgets('guest wallet error and retry remain accessible $locale',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      AuthStorage.instance.resetForTesting();
      await AuthStorage.instance.ensureInitialized();
      await show(
          tester,
          SizedBox(
              height: 1000,
              child: AppLocalizations(
                  locale: locale, child: const PointsScreen(threshold: 30000))),
          width: 320,
          scale: 2);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-retry')), findsOneWidget);
      expect(find.byType(WalletTransactionRow), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('wallet-retry')));
      await tester.tap(find.byKey(const ValueKey('wallet-retry')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('formatting follows Home grouping and preserves transaction precision',
      () {
    expect(formatWalletPoints(10643.21, isRu: true, balance: true), '10 643,2');
    expect(formatWalletPoints(10643, isRu: false, balance: true), '10 643');
    expect(formatWalletPoints(1234567.125, isRu: true), '1 234 567,125');
    expect(formatWalletPoints(-0.05, isRu: false), '−0.05');
    expect(formatWalletPoints(0.0000001, isRu: false), '0.0000001');
  });

  testWidgets(
      'locked state has progress and explanation without disabled action',
      (tester) async {
    await show(tester, balance());
    expect(find.byKey(const ValueKey('wallet-locked-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-view')), findsNothing);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('wallet-progress')))
            .value,
        closeTo(10643 / 30000, .00001));
  });

  testWidgets('eligible action preserves callback and accessible target',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await show(tester, balance(eligible: true, onView: () => taps++));
    await tester.tap(find.byKey(const ValueKey('wallet-view')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byKey(const ValueKey('wallet-locked-info')), findsNothing);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 360.0, 390.0, 440.0, 600.0]) {
      for (final scale in [1.0, 2.0, 3.2]) {
        testWidgets(
            '$platform $width scale $scale retains large amounts and long history text',
            (tester) async {
          await show(
              tester,
              Column(children: [
                balance(value: '999 999 999,9'),
                const SizedBox(height: 24),
                const WalletTransactionRow(
                    title: 'Зачислено',
                    date: '31.08.2026 • 09:26',
                    amount: 1234567.125,
                    isRu: true,
                    first: true),
                const WalletTransactionRow(
                    title: 'Sarflandi',
                    date: '05.02.2026 • 12:05',
                    amount: -987654.05,
                    isRu: false,
                    last: true),
              ]),
              width: width,
              scale: scale,
              platform: platform);
          expect(tester.takeException(), isNull);
          expect(find.text('+1 234 567,125'), findsOneWidget);
          expect(find.text('−987 654.05'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('transaction rows expose amount, direction and timestamp once',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await show(
        tester,
        const Column(children: [
          WalletTransactionRow(
              title: 'Зачислено',
              date: '31.08.2026 • 09:26',
              amount: 9143.25,
              isRu: true,
              first: true),
          WalletTransactionRow(
              title: 'Списано',
              date: '01.09.2026 • 10:30',
              amount: -143.25,
              isRu: true,
              last: true),
        ]));
    expect(
        find.bySemanticsLabel('Зачислено. +9 143,25 балл. 31.08.2026 • 09:26'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Списано. −143,25 балл. 01.09.2026 • 10:30'),
        findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('summary and filters remain readable and accessible',
      (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await show(
        tester,
        Column(children: [
          const WalletSummaryCard(
            creditLabel: 'Начислено',
            debitLabel: 'Списано',
            credited: 1234567.25,
            debited: 500.5,
            isRu: true,
          ),
          const SizedBox(height: 16),
          WalletFilterButton(
            key: const ValueKey('test-filter'),
            label: 'Всё время',
            selected: true,
            onPressed: () => taps++,
          ),
        ]),
        width: 320,
        scale: 2);
    expect(find.text('+1 234 567,25'), findsOneWidget);
    expect(find.text('−500,5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('test-filter')));
    expect(taps, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
