import 'dart:ui';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/locations/locations_screen.dart';
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

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  late int _selectedIndex;

  final List<Map<String, dynamic>> _navItems = [
    {"icon": Icons.home_rounded, "label": "Home"},
    {"icon": Icons.grid_view_rounded, "label": "Catalog"},
    {"icon": Icons.location_on_outlined, "label": "Locations"},
    {"icon": Icons.person_outline_rounded, "label": "Profile"},
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    CatalogScreen(),
    LocationsScreen(),
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
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void goToTab(int index) => _onTabSelected(index);
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _screens[_selectedIndex],
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Align(
            alignment: Alignment.bottomCenter,
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double safeOffset = bottomInset > 0 ? bottomInset * 0.20 : 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + safeOffset),
      child: SizedBox(
        height: floatingNavBarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    // Glassmorphism background for nav bar.
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(navItems.length + 1, (index) {
                      if (index == 2) {
                        return const SizedBox(width: 92);
                      }
                      final navIndex = index > 2 ? index - 1 : index;
                      final item = navItems[navIndex];
                      final isActive = navIndex == selectedIndex;
                      return _NavItem(
                        icon: item["icon"] as IconData,
                        isActive: isActive,
                        onTap: () => onItemSelected(navIndex),
                      );
                    }),
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
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00A86B);
    final fgColor =
        isActive ? Colors.white : primaryColor.withValues(alpha: 0.5);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        scale: isActive ? 1 : 0.9,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isActive ? primaryColor : Colors.white.withValues(alpha: 0.25),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: fgColor,
          ),
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
    const primaryColor = Color(0xFF00A86B);

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
        child: Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0DD277), Color(0xFF089D57)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.26),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.qr_code_rounded,
              size: 28,
              color: primaryColor.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}
