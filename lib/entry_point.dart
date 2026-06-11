import 'dart:ui';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/qr/qr_screen.dart';
import 'services/notification_socket_service.dart';

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key, this.initialIndex = 0});

  final int initialIndex;

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

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  late int _selectedIndex;
  Widget? _shellScreen;

  final List<Map<String, dynamic>> _navItems = [
    {"icon": Icons.home_rounded, "label": "Bosh sahifa"},
    {"icon": Icons.grid_view_rounded, "label": "Menyu"},
    {"icon": Icons.receipt_long_outlined, "label": "Buyurtmalarim"},
    {"icon": Icons.person_outline_rounded, "label": "Profil"},
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    CatalogScreen(),
    _OrdersPlaceholderScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // Start WebSocket in background after UI is ready.
    Future.microtask(() => NotificationSocketManager.instance.start());
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index && _shellScreen == null) return;
    setState(() {
      _selectedIndex = index;
      _shellScreen = null;
    });
  }

  void goToTab(int index) => _onTabSelected(index);

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _shellScreen == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeShellScreen();
      },
      child: Stack(
        children: [
          _shellScreen ?? _screens[_selectedIndex],
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: FloatingNavBar(
                navItems: _navItems,
                selectedIndex: _selectedIndex,
                onItemSelected: _onTabSelected,
                onQrPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingNavBar extends StatelessWidget {
  final List<Map<String, dynamic>> navItems;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onQrPressed;

  const FloatingNavBar({
    required this.navItems,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onQrPressed,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isCompact = availableWidth < 360;
        final navItemWidth = isCompact ? 48.0 : 52.0;
        final centerGap = isCompact ? 52.0 : 62.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset),
          child: SizedBox(
            width: double.infinity,
            height: floatingNavBarHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(navItems.length + 1, (index) {
                            if (index == 2) {
                              return SizedBox(width: centerGap);
                            }
                            final navIndex = index > 2 ? index - 1 : index;
                            final item = navItems[navIndex];
                            final isActive = navIndex == selectedIndex;
                            return _NavItem(
                              icon: item["icon"] as IconData,
                              label: item["label"] as String,
                              width: navItemWidth,
                              isActive: isActive,
                              onTap: () => onItemSelected(navIndex),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: _AnimatedQrButton(onPressed: onQrPressed),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double width;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.width,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00A86B);
    final fgColor = isActive ? primaryColor : const Color(0xFF72798B);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? primaryColor.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.55),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: fgColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fgColor,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedQrButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedQrButton({required this.onPressed});

  @override
  State<_AnimatedQrButton> createState() => _AnimatedQrButtonState();
}

class _AnimatedQrButtonState extends State<_AnimatedQrButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      lowerBound: 0.0,
      upperBound: 0.12,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          final scaleValue = 1 + _scale.value;
          return Transform.scale(
            scale: scaleValue,
            child: child,
          );
        },
        child: SizedBox(
          width: 64,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF13883F), Color(0xFF0A6F33)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.qr_code_rounded,
                  size: 25,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "QR / To‘lash",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF353B4B),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersPlaceholderScreen extends StatelessWidget {
  const _OrdersPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAFBFC),
      body: SafeArea(
        child: Center(
          child: Text(
            'Buyurtmalarim',
            style: TextStyle(
              color: Color(0xFF010F07),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
