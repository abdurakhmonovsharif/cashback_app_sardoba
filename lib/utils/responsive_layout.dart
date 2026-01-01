import 'package:flutter/material.dart';

/// Constrains very wide layouts (iPad/desktop) to a readable max width and
/// adds gentle side padding while leaving phones unchanged.
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

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
