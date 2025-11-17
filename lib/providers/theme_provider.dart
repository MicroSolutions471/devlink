// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/utility/customTheme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'themeMode'; // values: light, dark, system

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get themeMode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
    _startRemotePrimaryColorListener();
  }

  // Create provider with a preset mode (skip async load)
  ThemeProvider.preset(ThemeMode initial) {
    _mode = initial;
    _startRemotePrimaryColorListener();
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

  void _startRemotePrimaryColorListener() {
    try {
      FirebaseFirestore.instance
          .collection('appUpdates')
          .doc('colors')
          .snapshots()
          .listen(
            (snapshot) {
              final data = snapshot.data();
              print('[ThemeProvider] remote colors snapshot: $data');
              if (data == null) {
                return;
              }
              final value = data['primaryColor'];
              if (value is int) {
                primaryColor = Color(value);
                print(
                  '[ThemeProvider] primaryColor updated from int: $primaryColor',
                );
                notifyListeners();
              } else if (value is String && value.isNotEmpty) {
                final parsed = _parseRemoteHexColor(value);
                if (parsed != null) {
                  primaryColor = parsed;
                  print(
                    '[ThemeProvider] primaryColor updated from string: $parsed',
                  );
                  notifyListeners();
                } else {
                  print(
                    '[ThemeProvider] failed to parse string primaryColor: $value',
                  );
                }
              } else {
                print(
                  '[ThemeProvider] primaryColor is missing or empty in remote data',
                );
              }
            },
            onError: (error) {
              print(
                '[ThemeProvider] error in remote primaryColor stream: $error',
              );
            },
          );
    } catch (e) {
      print(
        '[ThemeProvider] exception while starting primaryColor listener: $e',
      );
    }
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

  Color? _parseRemoteHexColor(String input) {
    var hex = input.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return Color(value);
      }
    }
    return null;
  }
}
