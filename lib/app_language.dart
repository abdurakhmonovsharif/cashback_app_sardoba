import 'package:flutter/material.dart';

enum AppLocale { ru, uz }

extension AppLocaleExtension on AppLocale {
  Locale get flutterLocale {
    switch (this) {
      case AppLocale.ru:
        return const Locale('ru');
      case AppLocale.uz:
        return const Locale('uz');
    }
  }

  String get shortLabel {
    switch (this) {
      case AppLocale.ru:
        return 'Рус';
      case AppLocale.uz:
        return 'Oʻz';
    }
  }

  String get nativeName {
    switch (this) {
      case AppLocale.ru:
        return 'Русский';
      case AppLocale.uz:
        return 'Oʻzbekcha';
    }
  }

  String get apiCode {
    switch (this) {
      case AppLocale.ru:
        return 'ru';
      case AppLocale.uz:
        return 'uz';
    }
  }
}

class AppLanguage extends ChangeNotifier {
  AppLocale _locale = AppLocale.uz;

  AppLocale get locale => _locale;

  static final AppLanguage instance = AppLanguage._();

  AppLanguage._();

  void setLocale(AppLocale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
