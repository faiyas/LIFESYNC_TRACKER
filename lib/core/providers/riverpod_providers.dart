import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.light);

  void setTheme(AppThemeMode mode) {
    state = mode;
  }

  void toggleTheme() {
    if (state == AppThemeMode.dark) {
      state = AppThemeMode.light;
    } else {
      state = AppThemeMode.dark;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

class AuthLockNotifier extends StateNotifier<bool> {
  AuthLockNotifier() : super(false);

  void lock() {
    state = true;
  }

  void unlock() {
    state = false;
  }
}

final authLockProvider = StateNotifierProvider<AuthLockNotifier, bool>((ref) {
  return AuthLockNotifier();
});

final currencyProvider = StateProvider<String>((ref) => 'USD');
final activeProfileIdProvider = StateProvider<String>((ref) => 'default_profile');
