import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/components/floating_nav_bar.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/screens/profile/profile_screen.dart';
import 'package:sardoba_app/services/app_update_service.dart';
import 'package:sardoba_app/services/auth_storage.dart';

const _channel = MethodChannel('com.sardoba/app_update');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
    AppUpdateService.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    AppUpdateService.resetForTesting();
  });

  Future<void> show(WidgetTester tester, AppLocale locale, double width) async {
    tester.view.physicalSize = Size(width, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppLocalizations(
      locale: locale,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            textScaler: const TextScaler.linear(1.8),
          ),
          child: child!,
        ),
        home: Stack(children: [
          const ProfileScreen(),
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingNavBar(
              selectedIndex: 3,
              onItemSelected: (_) {},
              onQrPressed: () {},
            ),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final locale in AppLocale.values) {
      for (final signedIn in [false, true]) {
        testWidgets(
            'installed version footer: $platform / $locale / signed in $signedIn',
            (tester) async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                  _channel,
                  (_) async => {
                        'version': '8.4.2',
                        'platform':
                            platform == TargetPlatform.iOS ? 'ios' : 'android',
                      });
          if (signedIn) {
            await AuthStorage.instance.updateCurrentAccount(Account(
              name: 'Sinov',
              phone: '998900000000',
            ));
          }
          await show(tester, locale, signedIn ? 440 : 320);
          final footer = find.byKey(const ValueKey('profile-app-version'));
          await tester.drag(
              find.byType(SingleChildScrollView), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(
              find.text(locale == AppLocale.uz
                  ? 'Sardoba · Versiya 8.4.2'
                  : 'Sardoba · Версия 8.4.2'),
              findsOneWidget);
          expect(footer.hitTestable(), findsOneWidget);
          expect(tester.getRect(footer).bottom,
              lessThan(tester.getRect(find.byType(FloatingNavBar)).top));
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant({platform}));
      }
    }
  }

  testWidgets(
      'unavailable version leaves profile usable without invented metadata',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (_) async {
      throw PlatformException(code: 'APP_VERSION_UNAVAILABLE');
    });
    await show(tester, AppLocale.uz, 390);
    expect(find.byKey(const ValueKey('profile-app-version')), findsNothing);
    expect(find.text('Mehmon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
