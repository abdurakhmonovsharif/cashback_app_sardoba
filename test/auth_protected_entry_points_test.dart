import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/components/floating_nav_bar.dart';
import 'package:sardoba_app/entry_point.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/screens/auth/sign_in_screen.dart';
import 'package:sardoba_app/screens/profile/help_center_screen.dart';
import 'package:sardoba_app/screens/profile/profile_screen.dart';
import 'package:sardoba_app/screens/points/points_screen.dart';
import 'package:sardoba_app/screens/qr/qr_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:sardoba_app/services/notification_socket_service.dart';

void main() {
  final storage = AuthStorage.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage.resetForTesting();
    await storage.ensureInitialized();
  });

  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size viewport = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppLocalizations(
      locale: AppLocale.ru,
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: screen,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('guest QR action opens Login directly', (tester) async {
    addTearDown(NotificationSocketManager.instance.stop);
    await show(tester, const EntryPoint());
    await tester.pump(const Duration(seconds: 9));
    unawaited(NotificationSocketManager.instance.stop());

    await tester.tap(find.byKey(const ValueKey('nav-qr')));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(
      tester
          .widget<SignInScreen>(find.byType(SignInScreen))
          .destinationAfterLogin,
      isA<EntryPoint>(),
    );
    final destination = tester
        .widget<SignInScreen>(find.byType(SignInScreen))
        .destinationAfterLogin! as EntryPoint;
    expect(destination.initialShellScreen, isA<QrScreen>());
    expect(find.byType(QrScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in QR action opens QR screen', (tester) async {
    await storage.upsertAccount(
      const Account(name: 'Test User', phone: '998901234567'),
    );
    await storage.setCurrentUser('998901234567');
    await storage.saveAuthTokens(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
    );
    addTearDown(NotificationSocketManager.instance.stop);
    await show(tester, const EntryPoint());
    await tester.pump(const Duration(seconds: 9));
    unawaited(NotificationSocketManager.instance.stop());

    await tester.tap(find.byKey(const ValueKey('nav-qr')));
    await tester.pumpAndSettle();

    expect(find.byType(QrScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest Profile card opens Login', (tester) async {
    await show(tester, const ProfileScreen());

    await tester.tap(find.text('Войти / Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    final destination = tester
        .widget<SignInScreen>(find.byType(SignInScreen))
        .destinationAfterLogin;
    expect(destination, isA<EntryPoint>());
    expect((destination! as EntryPoint).initialIndex, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest points card opens Login', (tester) async {
    await show(tester, const ProfileScreen());

    await tester.tap(find.text('Количество баллов'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest Profile hides account settings and logout',
      (tester) async {
    await show(tester, const ProfileScreen());

    expect(find.text('Гость'), findsOneWidget);
    expect(find.text('Войти / Зарегистрироваться'), findsOneWidget);
    expect(find.text('Количество баллов'), findsOneWidget);
    expect(find.text('Авторизуйтесь, чтобы увидеть баллы.'), findsOneWidget);
    expect(find.text('Данные профиля'), findsNothing);
    expect(find.text('Сменить PIN'), findsNothing);
    expect(find.text('Уведомления'), findsNothing);
    expect(find.text('Выйти из аккаунта'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest Support opens without requiring authentication',
      (tester) async {
    await show(tester, const ProfileScreen());

    await tester.tap(find.text('Справка и поддержка'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest can change the app language from Profile', (tester) async {
    await show(tester, const ProfileScreen());
    await tester.ensureVisible(find.text('O\'zbekcha'));

    await tester.tap(find.text('O\'zbekcha'));
    await tester.pumpAndSettle();

    expect(AppLanguage.instance.locale, AppLocale.uz);
    expect(find.text('Войти / Зарегистрироваться'), findsOneWidget);
    expect(tester.takeException(), isNull);
    AppLanguage.instance.setLocale(AppLocale.ru);
  });

  testWidgets('Profile language selector clears the floating navigation',
      (tester) async {
    addTearDown(NotificationSocketManager.instance.stop);
    await show(tester, const EntryPoint(initialIndex: 3));
    await tester.pump(const Duration(seconds: 9));
    unawaited(NotificationSocketManager.instance.stop());
    final languageButton = find.text('O\'zbekcha');
    await tester.ensureVisible(languageButton);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(languageButton).bottom,
      lessThan(tester.getRect(find.byType(FloatingNavBar)).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in points card opens Points screen', (tester) async {
    await storage.upsertAccount(
      const Account(name: 'Test User', phone: '998901234567'),
    );
    await storage.setCurrentUser('998901234567');
    await show(tester, const ProfileScreen());

    await tester.tap(find.text('Количество баллов'));
    await tester.pumpAndSettle();

    expect(find.byType(PointsScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in Profile shows account settings and logout',
      (tester) async {
    await storage.upsertAccount(
      const Account(name: 'Test User', phone: '998901234567'),
    );
    await storage.setCurrentUser('998901234567');
    await show(tester, const ProfileScreen());

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Учётная запись'), findsOneWidget);
    expect(find.text('Данные профиля'), findsOneWidget);
    expect(find.text('PIN-код'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Справка и поддержка'), findsOneWidget);
    expect(find.text('Язык приложения'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest Profile cards and controls use compact target sizes',
      (tester) async {
    await show(tester, const ProfileScreen());
    final guestCard = tester.getRect(find.byKey(
      const ValueKey('profile-guest-card'),
    ));
    final bonusCard = tester.getRect(find.byKey(
      const ValueKey('profile-bonus-card'),
    ));
    await tester.ensureVisible(find.byKey(
      const ValueKey('profile-support-card'),
    ));
    final supportCard = tester.getRect(find.byKey(
      const ValueKey('profile-support-card'),
    ));
    final languageButton = tester.getRect(find.byKey(
      const ValueKey('profile-language-ru'),
    ));
    final loginButton = tester.getRect(
      find.widgetWithText(FilledButton, 'Войти / Зарегистрироваться'),
    );

    expect(guestCard.height, inInclusiveRange(150, 170));
    expect(bonusCard.height, inInclusiveRange(112, 132));
    expect(supportCard.height, inInclusiveRange(76, 84));
    expect(languageButton.height, 48);
    expect(loginButton.height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest Profile remains scrollable on narrow large-text screens',
      (tester) async {
    await show(
      tester,
      const ProfileScreen(),
      viewport: const Size(320, 568),
      textScale: 1.4,
    );
    await tester.ensureVisible(find.byKey(
      const ValueKey('profile-language-ru'),
    ));

    expect(find.byKey(const ValueKey('profile-support-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
