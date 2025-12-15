import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences extends ChangeNotifier {
  NotificationPreferences._();

  static final NotificationPreferences instance =
      NotificationPreferences._();

  static const _pushKey = 'notifications_push';
  static const _smsKey = 'notifications_sms';
  static const _emailKey = 'notifications_email';
  static const _orderKey = 'notifications_order_updates';
  static const _promotionsKey = 'notifications_promotions';

  SharedPreferences? _prefs;
  bool _initialized = false;

  bool _pushEnabled = true;
  bool _smsEnabled = false;
  bool _emailEnabled = false;
  bool _orderUpdates = true;
  bool _promotions = true;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _pushEnabled = _prefs!.getBool(_pushKey) ?? true;
    _smsEnabled = _prefs!.getBool(_smsKey) ?? false;
    _emailEnabled = _prefs!.getBool(_emailKey) ?? false;
    _orderUpdates = _prefs!.getBool(_orderKey) ?? true;
    _promotions = _prefs!.getBool(_promotionsKey) ?? true;
    _initialized = true;
    notifyListeners();
  }

  bool get pushEnabled => _pushEnabled;
  bool get smsEnabled => _smsEnabled;
  bool get emailEnabled => _emailEnabled;
  bool get orderUpdates => _orderUpdates;
  bool get promotions => _promotions;

  Future<void> setPushEnabled(bool value) async {
    await _setValue(_pushKey, value, () => _pushEnabled = value);
  }

  Future<void> setSmsEnabled(bool value) async {
    await _setValue(_smsKey, value, () => _smsEnabled = value);
  }

  Future<void> setEmailEnabled(bool value) async {
    await _setValue(_emailKey, value, () => _emailEnabled = value);
  }

  Future<void> setOrderUpdates(bool value) async {
    await _setValue(_orderKey, value, () => _orderUpdates = value);
  }

  Future<void> setPromotions(bool value) async {
    await _setValue(_promotionsKey, value, () => _promotions = value);
  }

  Future<void> _setValue(
    String key,
    bool value,
    VoidCallback updateField,
  ) async {
    await ensureInitialized();
    if (_prefs == null) return;
    updateField();
    await _prefs!.setBool(key, value);
    notifyListeners();
  }
}
