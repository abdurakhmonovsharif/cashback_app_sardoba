import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_language.dart';
import 'app_localizations.dart';
import 'constants.dart';
import 'entry_point.dart';
import 'navigation/app_navigator.dart';
import 'screens/onboarding/onboarding_scrreen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/pin/pin_lock_screen.dart';
import 'services/auth_storage.dart';
import 'services/push_notification_service.dart';
import 'services/session_sync_service.dart';
import 'utils/responsive_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AuthStorage.instance.ensureInitialized();
  await PushNotificationManager.instance.init();
  // Use edge-to-edge so status/navigation bars remain visible.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top]
  );

  runApp(const MyApp());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Allow portrait only
  ]);
  Future.microtask(() async {
    await SessionSyncService.instance.sync();
  });
}

/// ─────────────────────────────────────────
///   MY APP
/// ─────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLanguage _language = AppLanguage.instance;

  bool _splashFinished = false;
  _AppStartDestination? _destination;

  @override
  Widget build(BuildContext context) {
    final appName = "Sardoba";

    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        final locale = _language.locale;

        return AppLocalizations(
          locale: locale,
          child: MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNavigator.navigatorKey,
            locale: locale.flutterLocale,
            supportedLocales: const [Locale('ru'), Locale('uz')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.black),
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                systemOverlayStyle: SystemUiOverlayStyle.dark,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            builder: (context, child) => ResponsiveViewport(child: child),
            home: _buildHome(),
          ),
        );
      },
    );
  }

  /// ─────────────────────────────────────────
  ///   HOME BUILDER (MAIN APP FLOW)
  /// ─────────────────────────────────────────
  Widget _buildHome() {
    // 1) SPLASH KO‘RSATILADI
    if (!_splashFinished) {
      return SplashScreen(
        onFinished: () async {

          final dest = await _resolveStartDestination();

          if (!mounted) return;

          setState(() {
            _destination = dest;
            _splashFinished = true;
          });

        },
      );
    }

    // 2) SPLASH tugadi, destination hali hisoblanmagan bo‘lsa
    if (_destination == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 3) Destination bo‘yicha route tanlash
    switch (_destination!) {
      case _AppStartDestination.onboarding:
        return const OnboardingScreen();

      case _AppStartDestination.entry:
        return const EntryPoint();

      case _AppStartDestination.pin:
        return PinLockScreen(
          onUnlocked: (ctx) {
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const EntryPoint(),
              ),
            );
          },
        );
    }
  }

  /// ─────────────────────────────────────────
  ///   DESTINATION RESOLVER
  /// ─────────────────────────────────────────
  Future<_AppStartDestination> _resolveStartDestination() async {

    final storage = AuthStorage.instance;

    final hasUser = await storage.hasCurrentUser();

    final onboardingDone = await storage.isOnboardingCompleted();

    if (!hasUser) {
      return onboardingDone
          ? _AppStartDestination.entry
          : _AppStartDestination.onboarding;
    }

    final hasPin = await storage.hasPin();

    return hasPin ? _AppStartDestination.pin : _AppStartDestination.entry;
  }
}

enum _AppStartDestination { onboarding, entry, pin }
