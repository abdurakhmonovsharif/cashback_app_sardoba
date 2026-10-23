import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/main.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/screens/profile/profile_information_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.sardoba/app_update'),
            (_) async => {'updateAvailable': false});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.sardoba/app_update'), null);
  });

  for (final width in [
    320.0,
    360.0,
    390.0,
    440.0,
    600.0,
    840.0,
    1024.0,
    1032.0,
    1376.0
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('full window routes and body gutters: $width / $scale',
          (tester) async {
        final size = Size(width, width == 1376 ? 1032 : 1376);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // Use the real MaterialApp.builder to catch a constrained root Navigator.
        await tester.pumpWidget(const MyApp());
        final navigator = find.byType(Navigator);
        expect(tester.getRect(navigator), Offset.zero & size);
        expect(tester.getRect(find.byType(Scaffold)), Offset.zero & size);

        tester.state<NavigatorState>(navigator).push(PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              pageBuilder: (_, animation, secondaryAnimation) =>
                  ProfileInformationScreen(
                account: Account(name: 'Test', phone: '998900000000'),
              ),
            ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(
            tester.getRect(find.descendant(
                of: find.byType(ProfileInformationScreen),
                matching: find.byType(Scaffold))),
            Offset.zero & size);
        final appBar = tester.getRect(find.byType(AppBar));
        expect(appBar.left, 0);
        expect(appBar.right, size.width);
        final scroll = find.byKey(const ValueKey('profile-information-scroll'));
        final rect = tester.getRect(scroll);
        final contentWidth = width >= 1024
            ? math.min(width, 1100) - 64
            : width >= 600
                ? math.min(width, 900) - 48
                : width;
        expect(rect.width, contentWidth);
        expect(rect.center.dx, size.width / 2);
        expect(rect.bottom, size.height);
        expect(MediaQuery.sizeOf(tester.element(scroll)), size);
        expect(MediaQuery.textScalerOf(tester.element(scroll)).scale(16),
            16 * scale);

        // Route overlays must also cover the complete window, including gutters.
        showDialog<void>(
          context: tester.element(scroll),
          builder: (_) => const AlertDialog(content: Text('Test')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
            tester.getRect(find.byType(ModalBarrier).last), Offset.zero & size);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
