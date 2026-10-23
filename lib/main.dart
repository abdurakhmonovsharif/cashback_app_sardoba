import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_language.dart';
import 'app_localizations.dart';
import 'components/app_input_decoration.dart';
import 'constants.dart';
import 'entry_point.dart';
import 'navigation/app_navigator.dart';
import 'screens/onboarding/onboarding_scrreen.dart';
import 'screens/onboarding/app_update_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'services/app_api_client.dart';
import 'services/app_update_service.dart';
import 'screens/pin/pin_lock_screen.dart';
import 'services/auth_storage.dart';
import 'services/push_notification_service.dart';
import 'services/session_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    return true;
  }());

  await AuthStorage.instance.ensureInitialized();
  // Use edge-to-edge so status/navigation bars remain visible.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top]);

  runApp(const MyApp());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Allow portrait only
  ]);
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
  bool _updateRequired = false;
  bool _optionalUpdateDialogOpen = false;
  bool _requiredRouteShown = false;
  RequiredAppUpdate? _requiredUpdate;
  _AppStartDestination? _destination;

  @override
  void initState() {
    super.initState();
    _requiredUpdate = AppApiClient.requiredUpdate.value;
    _updateRequired = _requiredUpdate != null;
    _requiredRouteShown = _updateRequired;
    AppApiClient.requiredUpdate.addListener(_onRequiredUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startPostUpdateServices();
      unawaited(_checkForOptionalUpdate());
    });
  }

  @override
  void dispose() {
    AppApiClient.requiredUpdate.removeListener(_onRequiredUpdate);
    super.dispose();
  }

  void _startPostUpdateServices() {
    unawaited(PushNotificationManager.instance.init().catchError(
      (Object error, StackTrace stackTrace) {
        debugPrint('Push notification initialization failed: $error');
      },
    ));
    unawaited(SessionSyncService.instance.sync());
  }

  void _onRequiredUpdate() {
    if (!mounted) return;
    setState(() {
      _requiredUpdate = AppApiClient.requiredUpdate.value;
      _updateRequired = _requiredUpdate != null;
    });
    if (_updateRequired && !_requiredRouteShown) {
      _requiredRouteShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = AppNavigator.navigatorKey.currentState;
        if (navigator == null || !navigator.mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => _requiredUpdateScreen(),
          ),
          (_) => false,
        );
      });
    }
    if (_optionalUpdateDialogOpen) {
      AppNavigator.navigatorKey.currentState?.pop(false);
    }
  }

  Future<void> _checkForOptionalUpdate() async {
    if (!await AppUpdateService.checkForAvailableUpdate() ||
        !mounted ||
        _updateRequired) {
      return;
    }
    final navigatorState = AppNavigator.navigatorKey.currentState;
    if (navigatorState == null || !navigatorState.mounted) return;
    final context = navigatorState.context;
    if (!context.mounted) return;
    final strings = AppLocalizations.of(context);
    _optionalUpdateDialogOpen = true;
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.optionalUpdateTitle),
        content: Text(strings.optionalUpdateMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.updateLater),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.updateAction),
          ),
        ],
      ),
    );
    _optionalUpdateDialogOpen = false;
    if (shouldUpdate == true && mounted) {
      await AppUpdateService.openOptionalUpdate();
    }
  }

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
              fontFamily: 'SF Pro Text',
              scaffoldBackgroundColor: screenBackgroundColor,
              inputDecorationTheme: AppInputDecoration.theme,
              cardTheme: const CardThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(AppRadius.card)),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: screenBackgroundColor,
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
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              assert(() {
                debugPaintBaselinesEnabled = false;
                debugPaintSizeEnabled = false;
                debugPaintLayerBordersEnabled = false;
                debugRepaintRainbowEnabled = false;
                return true;
              }());
              // Routes and system-bar backgrounds must fill the window.
              // Responsive width limits belong inside each Scaffold's body.
              return child ?? const SizedBox.shrink();
            },
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
    if (_updateRequired) {
      return _requiredUpdateScreen();
    }

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

  Widget _requiredUpdateScreen() {
    return AppUpdateRequiredScreen(
      onUpdate: () => unawaited(AppUpdateService.openMandatoryUpdate(
        iosStoreUrl: _requiredUpdate?.iosStoreUrl,
        androidStoreUrl: _requiredUpdate?.androidStoreUrl,
      )),
    );
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
