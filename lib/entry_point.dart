import 'dart:async';

import 'package:flutter/material.dart';
import 'components/floating_nav_bar.dart';
import 'navigation/app_nav_bar_layout.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/locations/locations_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/qr/qr_screen.dart';
import 'services/auth_storage.dart';
import 'services/notification_socket_service.dart';

class EntryPoint extends StatefulWidget {
  const EntryPoint({
    super.key,
    this.initialIndex = 0,
    this.initialShellScreen,
  });

  final int initialIndex;
  final Widget? initialShellScreen;

  static bool openCatalog(BuildContext context, {String? categoryId}) {
    final state = context.findAncestorStateOfType<_EntryPointState>();
    if (state == null) return false;
    state.openCatalog(categoryId);
    return true;
  }

  static bool selectTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_EntryPointState>();
    if (state == null) return false;
    state.goToTab(index);
    return true;
  }

  static bool showShellScreen(BuildContext context, Widget screen) {
    final state = context.findAncestorStateOfType<_EntryPointState>();
    if (state == null) return false;
    state.showShellScreen(screen);
    return true;
  }

  static bool openQr(BuildContext context) {
    final state = context.findAncestorStateOfType<_EntryPointState>();
    if (state == null) return false;
    unawaited(state._openQrOrLogin());
    return true;
  }

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  late int _selectedIndex;
  Widget? _shellScreen;
  String? _catalogCategoryId;
  int? _catalogReturnIndex;

  List<Widget> get _screens => [
        const HomeScreen(),
        CatalogScreen(initialCategoryId: _catalogCategoryId),
        const LocationsScreen(),
        const ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _shellScreen = widget.initialShellScreen;
    // Start WebSocket in background after UI is ready.
    Future.microtask(() => NotificationSocketManager.instance.start());
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index && _shellScreen == null) return;
    setState(() {
      _selectedIndex = index;
      _shellScreen = null;
      _catalogReturnIndex = null;
    });
  }

  void goToTab(int index) => _onTabSelected(index);

  void openCatalog(String? categoryId) {
    setState(() {
      if (_selectedIndex != 1) _catalogReturnIndex = _selectedIndex;
      _catalogCategoryId = categoryId;
      _selectedIndex = 1;
      _shellScreen = null;
    });
  }

  void showShellScreen(Widget screen) {
    setState(() {
      _shellScreen = screen;
    });
  }

  void _closeShellScreen() {
    if (_shellScreen == null) return;
    setState(() {
      _shellScreen = null;
    });
  }

  Future<void> _openQrOrLogin() async {
    final account = await AuthStorage.instance.getCurrentAccount();
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => account == null
            ? const SignInScreen(
                destinationAfterLogin: EntryPoint(
                  initialShellScreen: QrScreen(),
                ),
              )
            : const QrScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppNavBarViewport(
      child: PopScope(
        canPop: _shellScreen == null && _catalogReturnIndex == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_shellScreen != null) {
            _closeShellScreen();
          } else if (_catalogReturnIndex != null) {
            _onTabSelected(_catalogReturnIndex!);
          }
        },
        child: Stack(
          children: [
            _shellScreen ?? _screens[_selectedIndex],
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppNavBarLayout.maxWidth),
                child: FloatingNavBar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onTabSelected,
                  onQrPressed: _openQrOrLogin,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
