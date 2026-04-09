import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _load();
  }



  void toggleTheme() {
    final box = Hive.box('settings');
    final isDark = state == ThemeMode.dark;

    state = isDark ? ThemeMode.light : ThemeMode.dark;

    box.put('darkMode', !isDark);
  }

  void _load() {
    final box = Hive.box('settings');
    final isDark = box.get('darkMode', defaultValue: true);
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}