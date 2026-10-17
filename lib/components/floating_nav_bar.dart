import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../constants.dart';
import '../navigation/app_nav_bar_layout.dart';

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onQrPressed,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onQrPressed;

  @override
  Widget build(BuildContext context) {
    final layout = AppNavBarLayout.of(context);
    final colors = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context);
    final destinations = [
      (icon: Icons.home_outlined, selected: Icons.home_rounded, tab: 0),
      (
        icon: Icons.grid_view_outlined,
        selected: Icons.grid_view_rounded,
        tab: 1
      ),
      (icon: Icons.qr_code_rounded, selected: Icons.qr_code_rounded, tab: null),
      (
        icon: Icons.location_on_outlined,
        selected: Icons.location_on_rounded,
        tab: 2
      ),
      (
        icon: Icons.person_outline_rounded,
        selected: Icons.person_rounded,
        tab: 3
      ),
    ];

    return Padding(
      padding: layout.padding,
      child: SizedBox(
        height: layout.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: AppNavBarLayout.panelTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.10),
                      blurRadius: 26,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Material(
                  key: const ValueKey('nav-panel'),
                  color: colors.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppNavBarLayout.horizontalContentPadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(destinations.length, (index) {
                    final destination = destinations[index];
                    final tab = destination.tab;
                    final isQr = tab == null;
                    final isActive = !isQr && tab == selectedIndex;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppNavBarLayout.itemSpacing / 2,
                        ),
                        child: _NavItem(
                          key: ValueKey(isQr ? 'nav-qr' : 'nav-tab-$tab'),
                          icon: isActive
                              ? destination.selected
                              : destination.icon,
                          label: layout.labels[index],
                          semanticLabel: isQr
                              ? strings.qrScreenTitle
                              : tab == 0
                                  ? strings.navHomeAccessibility
                                  : layout.labels[index],
                          layout: layout,
                          isActive: isActive,
                          isQr: isQr,
                          onTap: isQr ? onQrPressed : () => onItemSelected(tab),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.layout,
    required this.isActive,
    required this.isQr,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final AppNavBarLayout layout;
  final bool isActive;
  final bool isQr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isActive ? colors.primary : colors.onSurface;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return Semantics(
      button: true,
      selected: isQr ? null : isActive,
      inMutuallyExclusiveGroup: !isQr,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: Padding(
          padding: EdgeInsets.only(
            top: isQr ? 0 : AppNavBarLayout.panelTop,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Column(
                children: [
                  SizedBox(
                    height: isQr
                        ? 0
                        : AppNavBarLayout.tabTop - AppNavBarLayout.panelTop,
                  ),
                  SizedBox(
                    height:
                        isQr ? layout.qrDiameter : AppNavBarLayout.iconHeight,
                    child: Center(
                      child: isQr
                          ? Container(
                              key: const ValueKey('nav-qr-visual'),
                              width: layout.qrDiameter,
                              height: layout.qrDiameter,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLowest,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        colors.shadow.withValues(alpha: 0.16),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      primaryColor,
                                      AppBrandColors.deepGreenShade,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_rounded,
                                  size: 27,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeOut,
                              width: 48,
                              height: AppNavBarLayout.iconHeight,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colors.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(19),
                              ),
                              alignment: Alignment.center,
                              child: Icon(icon, size: 24, color: foreground),
                            ),
                    ),
                  ),
                  SizedBox(
                    height: isQr
                        ? AppNavBarLayout.tabTop +
                            AppNavBarLayout.iconHeight +
                            AppNavBarLayout.labelGap -
                            layout.qrDiameter
                        : AppNavBarLayout.labelGap,
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: layout.labelStyle.copyWith(
                      color: foreground,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
