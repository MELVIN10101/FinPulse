import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';

class ThemeManager extends ChangeNotifier {
  static final ThemeManager instance = ThemeManager._internal();
  ThemeManager._internal();

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    try {
      final mode = await DatabaseHelper.instance.getSetting('dark_mode');
      if (mode == 'false') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    } catch (_) {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      await DatabaseHelper.instance.setSetting('dark_mode', isDark.toString());
    } catch (_) {}
    notifyListeners();
  }
}
