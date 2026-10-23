import 'package:flutter/material.dart';

import '../constants.dart';

/// Shared form-field appearance, based on the app's Search input.
abstract final class AppInputDecoration {
  static const BorderRadius borderRadius =
      BorderRadius.all(Radius.circular(AppRadius.control));
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: defaultPadding,
    vertical: 14,
  );

  static TextStyle labelTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: titleColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ) ??
        const TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        );
  }

  static const OutlineInputBorder enabledBorder = OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: appBorderColor),
  );
  static const OutlineInputBorder focusedBorder = OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: primaryColor, width: 1.5),
  );
  static const OutlineInputBorder errorBorder = OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: Colors.redAccent),
  );
  static const OutlineInputBorder focusedErrorBorder = OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
  );

  static const InputDecorationTheme theme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: contentPadding,
    border: enabledBorder,
    enabledBorder: enabledBorder,
    disabledBorder: enabledBorder,
    focusedBorder: focusedBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: focusedErrorBorder,
  );

  static BoxDecoration cupertino({
    required bool focused,
    bool hasError = false,
  }) {
    final color = hasError
        ? Colors.redAccent
        : focused
            ? primaryColor
            : appBorderColor;
    return BoxDecoration(
      color: Colors.white,
      borderRadius: borderRadius,
      border: Border.all(
        color: color,
        width: focused ? 1.5 : 1,
      ),
    );
  }
}
