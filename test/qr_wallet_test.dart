import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/models/loyalty_qr.dart';
import 'package:sardoba_app/screens/qr/qr_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:sardoba_app/theme.dart';

const _fixtureTrack = 'SARDOBATEST-TRACK-0123456789';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
    await AuthStorage.instance.updateCurrentAccount(const Account(
      name: 'Test Customer',
      phone: '+998901234567',
      cardTracks: [_fixtureTrack],
      loyaltyQr: LoyaltyQr(status: 'confirmed', payload: _fixtureTrack),
    ));
  });

  Future<void> show(WidgetTester tester,
      {required Size size, double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.ru,
      child: MaterialApp(
        theme: buildThemeData(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child:
                QrScreen(loadAccount: AuthStorage.instance.getCurrentAccount),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 480),
    const Size(320, 700),
    const Size(360, 640),
    const Size(390, 844),
    const Size(440, 956),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0, 3.2]) {
      testWidgets('QR wallet fits $size at text scale $scale', (tester) async {
        await show(tester, size: size, textScale: scale);
        final qr = tester.widget<QrImageView>(
            find.byKey(const ValueKey('loyalty-qr-image')));
        final visibleCodeSize = qr.size! - qr.padding.horizontal;
        expect(visibleCodeSize, inInclusiveRange(210, 280));
        if (size.width >= 390) {
          expect(visibleCodeSize, inInclusiveRange(260, 280));
        }
        final modules = QrValidator.validate(
          data: _fixtureTrack,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        ).qrCode!.moduleCount;
        expect(qr.padding.left,
            greaterThanOrEqualTo(visibleCodeSize / modules * 4 - 0.001));
        final qrRect = tester.getRect(find.byKey(const ValueKey('loyalty-qr')));
        expect(tester.getTopLeft(find.text('Test Customer')).dy,
            greaterThan(qrRect.bottom));
        expect(find.byKey(const ValueKey('qr-wallet-card')), findsOneWidget);
        final group =
            tester.getRect(find.byKey(const ValueKey('qr-wallet-content')));
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        if (group.height <= viewport.height - 32) {
          expect(group.center.dy, closeTo(viewport.center.dy, 1));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('profile is masked while the QR keeps its own payload',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, size: const Size(390, 844));
    expect(find.text('+998 •• ••• 4567'), findsOneWidget);
    expect(find.text('+998901234567'), findsNothing);
    expect(
        find.bySemanticsLabel('QR-код для начисления баллов'), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    final capturePath = Platform.environment['QR_TEST_IMAGE_PATH'];
    if (capturePath != null && capturePath.isNotEmpty) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('loyalty-qr')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capturePath).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('guest keeps a reachable login action', (tester) async {
    await AuthStorage.instance.clearCurrentUser();
    await show(tester, size: const Size(320, 700), textScale: 2);

    final login = find.byKey(const ValueKey('qr-login'));
    expect(login, findsOneWidget);
    expect(tester.getSize(login).height, greaterThanOrEqualTo(48));
    expect(find.byType(QrImageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account without a code retains the missing-code state',
      (tester) async {
    await AuthStorage.instance.updateCurrentAccount(const Account(
      name: 'Test Customer',
      phone: '',
      cardTracks: [],
    ));
    await show(tester, size: const Size(390, 844));

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('qr-wallet-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone never becomes a QR payload when cards are absent',
      (tester) async {
    await AuthStorage.instance.updateCurrentAccount(const Account(
      name: 'Test Customer',
      phone: '+998 90 123 45 67',
      cardTracks: [],
    ));
    await show(tester, size: const Size(390, 844));

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('qr-retry')), findsOneWidget);
  });

  testWidgets('legacy cards and phone never produce an unconfirmed QR',
      (tester) async {
    await AuthStorage.instance.updateCurrentAccount(const Account(
      name: 'Fixture',
      phone: '+998901234567',
      cardTracks: [_fixtureTrack],
      loyaltyQr: LoyaltyQr(status: 'pending', payload: _fixtureTrack),
    ));
    await show(tester, size: const Size(320, 480), textScale: 3.2);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Карта готовится'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending refresh shows only the newly confirmed server payload',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.ru,
      child: MaterialApp(
          theme: buildThemeData(),
          home: QrScreen(loadAccount: () async {
            calls++;
            return Account(
                name: 'Fixture',
                phone: '+998901234567',
                cardTracks: const ['WRONG'],
                loyaltyQr: calls == 1
                    ? const LoyaltyQr(status: 'pending')
                    : const LoyaltyQr(
                        status: 'confirmed', payload: _fixtureTrack));
          })),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pending polling stops after six refreshes and disposal cancels it',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.ru,
      child: MaterialApp(
          theme: buildThemeData(),
          home: QrScreen(loadAccount: () async {
            calls++;
            return const Account(
                name: 'Fixture',
                phone: '+998901234567',
                loyaltyQr: LoyaltyQr(status: 'pending'));
          })),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
    expect(calls, 7);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.byKey(const ValueKey('qr-retry')));
    await tester.pumpAndSettle();
    expect(calls, 8);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 8);
  });

  testWidgets('network error hides QR and offers accessible retry',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var fail = true;
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.ru,
      child: MaterialApp(
          theme: buildThemeData(),
          home: QrScreen(loadAccount: () async {
            if (fail) throw StateError('offline');
            return const Account(
                name: 'Fixture',
                phone: '+998901234567',
                loyaltyQr:
                    LoyaltyQr(status: 'confirmed', payload: _fixtureTrack));
          })),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    fail = false;
    await tester.tap(find.byKey(const ValueKey('qr-retry')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
      'cached confirmed account without an authenticated session shows no QR',
      (tester) async {
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.ru,
      child: MaterialApp(theme: buildThemeData(), home: const QrScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('qr-login')), findsOneWidget);
  });

  testWidgets('long customer name stays scrollable at large text size',
      (tester) async {
    await AuthStorage.instance.updateCurrentAccount(const Account(
      name: 'Test Customer With A Very Long Family Name',
      phone: '+998901234567',
      cardTracks: [_fixtureTrack],
      loyaltyQr: LoyaltyQr(status: 'confirmed', payload: _fixtureTrack),
    ));
    await show(tester, size: const Size(320, 480), textScale: 3.2);
    final footer =
        find.text('Держите код на экране, пока кассир его сканирует.');
    await Scrollable.ensureVisible(tester.element(footer), alignment: 1);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(footer).dy, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });
}
