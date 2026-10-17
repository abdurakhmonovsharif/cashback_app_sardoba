import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final GestureTapCallback? press;
  final bool isLoading;
  final bool uppercase;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.press,
    this.isLoading = false,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    const verticalPadding = EdgeInsets.symmetric(vertical: defaultPadding);
    final enabled = !isLoading && press != null;
    return SizedBox(
      width: double.infinity,
      child: Platform.isIOS
          ? CupertinoButton(
              padding: verticalPadding,
              color: primaryColor,
              disabledColor: primaryColor.withValues(alpha: 0.35),
              onPressed: enabled ? press : null,
              child: isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : buildText(context),
            )
          : ElevatedButton(
              style: TextButton.styleFrom(
                padding: verticalPadding,
                backgroundColor: primaryColor,
                disabledBackgroundColor: primaryColor.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
              ),
              onPressed: enabled ? press : null,
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : buildText(context),
            ),
    );
  }

  Text buildText(BuildContext context) {
    return Text(
      uppercase ? text.toUpperCase() : text,
      style: kButtonTextStyle,
    );
  }
}
