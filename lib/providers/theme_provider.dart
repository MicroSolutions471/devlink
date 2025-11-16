import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'themeMode'; // values: light, dark, system

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get themeMode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  // Create provider with a preset mode (skip async load)
  ThemeProvider.preset(ThemeMode initial) {
    _mode = initial;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      case 'system':
        _mode = ThemeMode.system;
        break;
      case 'light':
      default:
        _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.system
          ? 'system'
          : 'light',
    );
  }

  Future<void> toggleDarkLight() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  // Helpers for main.dart to synchronously fetch the saved mode before runApp
  static ThemeMode _parse(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static Future<ThemeMode> readSaved() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_key));
  }
}
