import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final GestureTapCallback press;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.press,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    EdgeInsets verticalPadding =
        const EdgeInsets.symmetric(vertical: defaultPadding);
    return SizedBox(
      width: double.infinity,
      child: Platform.isIOS
          ? CupertinoButton(
              padding: verticalPadding,
              color: primaryColor,
              onPressed: isLoading ? null : press,
              child: isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : buildText(context),
            )
          : ElevatedButton(
              style: TextButton.styleFrom(
                padding: verticalPadding,
                backgroundColor: primaryColor,
              ),
              onPressed: isLoading ? null : press,
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
      text.toUpperCase(),
      style: kButtonTextStyle,
    );
  }
}
