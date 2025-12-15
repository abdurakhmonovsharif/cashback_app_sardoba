import 'package:flutter/material.dart';

import '../constants.dart';

SnackBar navAwareSnackBar(
  BuildContext context, {
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  Color? backgroundColor,
}) {
  final bottomMargin = navAwareBottomPadding(context, extra: 12);
  return SnackBar(
    content: content,
    action: action,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(
      defaultPadding,
      0,
      defaultPadding,
      bottomMargin,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    elevation: 8,
    dismissDirection: DismissDirection.horizontal,
    backgroundColor: backgroundColor,
  );
}

void showNavAwareSnackBar(
  BuildContext context, {
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  Color? backgroundColor,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    navAwareSnackBar(
      context,
      content: content,
      action: action,
      duration: duration,
      backgroundColor: backgroundColor,
    ),
  );
}
