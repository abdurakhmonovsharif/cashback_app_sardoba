import 'package:flutter/material.dart';

/// Constrains page content to a readable width while leaving phones unchanged.
/// Use inside Scaffold.body, never around the root Navigator or Scaffold:
/// route backgrounds and system bars must retain the full window bounds.
class ResponsiveViewport extends StatelessWidget {
  const ResponsiveViewport({
    super.key,
    required this.child,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 1024,
    this.tabletMaxWidth = 900,
    this.desktopMaxWidth = 1100,
  });

  final Widget? child;
  final double tabletBreakpoint;
  final double desktopBreakpoint;
  final double tabletMaxWidth;
  final double desktopMaxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTablet = width >= tabletBreakpoint;
        final isDesktop = width >= desktopBreakpoint;

        final maxWidth = isDesktop
            ? desktopMaxWidth
            : isTablet
                ? tabletMaxWidth
                : width;

        final horizontalPadding = isDesktop
            ? 32.0
            : isTablet
                ? 24.0
                : 0.0;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              // A short scrollable must still fill the Scaffold body rather
              // than shrink and become vertically centered.
              minHeight:
                  constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
