import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_localizations.dart';

/// The app's tablet gutters reduce the shell width below the window width.
/// Share that actual width with both navigation and content inset calculations.
class AppNavBarViewport extends StatelessWidget {
  const AppNavBarViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          size: Size(constraints.maxWidth, media.size.height),
        ),
        child: child,
      );
    });
  }
}

/// Shared measurements keep scroll content clear of the floating navigation,
/// including when localized labels wrap at larger system text sizes.
class AppNavBarLayout {
  const AppNavBarLayout._({
    required this.labels,
    required this.labelStyle,
    required this.height,
    required this.qrDiameter,
    required this.padding,
  });

  static const maxWidth = 760.0;
  static const minimumHeight = 96.0;
  static const panelTop = 14.0;
  static const tabTop = 27.0;
  static const horizontalContentPadding = 6.0;
  static const itemSpacing = 4.0;
  static const iconHeight = 34.0;
  static const labelGap = 4.0;
  static const bottomContentPadding = 16.0;

  final List<String> labels;
  final TextStyle labelStyle;
  final double height;
  final double qrDiameter;
  final EdgeInsets padding;

  static AppNavBarLayout of(BuildContext context) {
    final media = MediaQuery.of(context);
    final strings = AppLocalizations.of(context);
    final labels = [
      strings.navHome,
      strings.navMenu,
      strings.navQr,
      strings.navLocations,
      strings.profileTitle,
    ];
    final width = math.min(media.size.width, maxWidth);
    final margin = width < 600 ? 8.0 : 16.0;
    final padding = EdgeInsets.fromLTRB(
      margin + media.padding.left,
      0,
      margin + media.padding.right,
      media.padding.bottom + 8,
    );
    final labelWidth = math.max(
      1.0,
      (width - padding.horizontal - horizontalContentPadding * 2) /
              labels.length -
          itemSpacing,
    );
    final labelStyle = Theme.of(context).textTheme.labelMedium!.copyWith(
          fontSize: 12,
          height: 1.15,
          letterSpacing: 0,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        );
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
      )..layout(maxWidth: labelWidth);
      labelHeight = math.max(labelHeight, painter.height.ceilToDouble());
      painter.dispose();
    }
    return AppNavBarLayout._(
      labels: labels,
      labelStyle: labelStyle,
      qrDiameter: math.min(60, labelWidth),
      height: math.max(
        minimumHeight,
        tabTop + iconHeight + labelGap + labelHeight + bottomContentPadding,
      ),
      padding: padding,
    );
  }
}
