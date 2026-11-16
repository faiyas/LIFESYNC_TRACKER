import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/google_sheets_backup_service.dart';

enum AppThemeMode { light, dark, highContrast }

class AppProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _isLocked = false;
  String? _pinCode;
  String _activeProfileId = 'default_profile';

  AppThemeMode get themeMode => _themeMode;
  bool get isLocked => _isLocked;
  String? get pinCode => _pinCode;
  String get activeProfileId => _activeProfileId;

  AppProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode') ?? 'dark';
    if (themeStr == 'light') {
      _themeMode = AppThemeMode.light;
    } else if (themeStr == 'highContrast') {
      _themeMode = AppThemeMode.highContrast;
    } else {
      _themeMode = AppThemeMode.dark;
    }

    _pinCode = prefs.getString('security_pin');
    if (_pinCode != null && _pinCode!.isNotEmpty) {
      _isLocked = true;
    }

    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> setPinCode(String? pin) async {
    _pinCode = pin;
    final prefs = await SharedPreferences.getInstance();
    if (pin == null || pin.isEmpty) {
      await prefs.remove('security_pin');
      _isLocked = false;
    } else {
      await prefs.setString('security_pin', pin);
    }
    notifyListeners();
  }

  bool unlockWithPin(String inputPin) {
    if (_pinCode != null && inputPin == _pinCode) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockApp() {
    if (_pinCode != null && _pinCode!.isNotEmpty) {
      _isLocked = true;
      notifyListeners();
    }
  }

  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  void refreshData() {
    _dataVersion++;
    notifyListeners();
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }

  void notifyDataChanged() {
    _dataVersion++;
    notifyListeners();
    GoogleSheetsBackupService.instance.triggerDebouncedSync();
  }
}
