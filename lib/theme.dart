import 'package:flutter/material.dart';

import 'components/app_input_decoration.dart';
import 'constants.dart';

ThemeData buildThemeData() {
  return ThemeData(
    primaryColor: accentColor,

    scaffoldBackgroundColor: Colors.white,
    fontFamily: "SF Pro Text",
    // textTheme: textTheme().apply(displayColor: titleColor),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    inputDecorationTheme: AppInputDecoration.theme,
    buttonTheme: buttonThemeData,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

final InputDecorationTheme inputDecorationTheme = AppInputDecoration.theme;

const ButtonThemeData buttonThemeData = ButtonThemeData(
  shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8))),
);
