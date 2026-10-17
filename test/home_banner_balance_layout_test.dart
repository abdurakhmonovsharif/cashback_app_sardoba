import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/screens/home/components/home_banner_balance_layout.dart';

void main() {
  Future<void> showLayout(
    WidgetTester tester, {
    required double width,
    double horizontalPadding = 16,
  }) async {
    final size = Size(width, 900);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: HomeBannerBalanceLayout(
                  banner: const SizedBox(
                    key: ValueKey('layout-banner'),
                    height: 150,
                  ),
                  balance: const SizedBox(
                    key: ValueKey('layout-balance'),
                    height: 104,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [
    320.0,
    390.0,
    600.0,
    768.0,
    839.0,
    840.0,
    1024.0,
    1080.0,
    1366.0
  ]) {
    testWidgets('banner and balance fill available width at $width dp',
        (tester) async {
      await showLayout(tester, width: width);

      final banner =
          tester.getRect(find.byKey(const ValueKey('layout-banner')));
      final balance =
          tester.getRect(find.byKey(const ValueKey('layout-balance')));
      expect(banner.left, closeTo(16, 0.01));
      expect(banner.right, closeTo(width - 16, 0.01));
      expect(balance.left, closeTo(banner.left, 0.01));
      expect(balance.right, closeTo(banner.right, 0.01));
      expect(balance.top - banner.bottom, closeTo(12, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses the parent insets in a narrow tablet window',
      (tester) async {
    await showLayout(tester, width: 840, horizontalPadding: 48);

    final banner = tester.getRect(find.byKey(const ValueKey('layout-banner')));
    final balance =
        tester.getRect(find.byKey(const ValueKey('layout-balance')));
    expect(banner.left, closeTo(48, 0.01));
    expect(banner.right, closeTo(792, 0.01));
    expect(balance.width, closeTo(banner.width, 0.01));
    expect(balance.top, greaterThan(banner.bottom));
    expect(tester.takeException(), isNull);
  });
}
