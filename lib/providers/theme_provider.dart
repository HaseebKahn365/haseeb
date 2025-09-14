import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final ThemeMode mode;
  final Color seedColor;

  ThemeState({required this.mode, required this.seedColor});

  ThemeState copyWith({ThemeMode? mode, Color? seedColor}) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
    : super(ThemeState(mode: ThemeMode.system, seedColor: Colors.blue)) {
    _loadFromPrefs();
  }

  static const _modeKey = 'theme_mode';
  static const _colorKey = 'theme_seed_color';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_modeKey);
      final colorValue = prefs.getInt(_colorKey);
      ThemeMode mode = state.mode;
      Color seed = state.seedColor;
      if (modeIndex != null) {
        mode =
            ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)];
      }
      if (colorValue != null) {
        seed = Color(colorValue);
      }
      state = ThemeState(mode: mode, seedColor: seed);
    } catch (_) {
      // ignore and keep defaults
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _saveToPrefs();
  }

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
    _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_modeKey, state.mode.index);
      await prefs.setInt(_colorKey, state.seedColor.value);
    } catch (e) {
      log('Error saving theme preferences: $e');
    }
  }
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((
  ref,
) {
  return ThemeNotifier();
});

final themeDataProvider = Provider<ThemeData>((ref) {
  final state = ref.watch(themeNotifierProvider);
  final colorScheme = ColorScheme.fromSeed(seedColor: state.seedColor);
  final baseText = GoogleFonts.rubikTextTheme();
  final themedText = baseText.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  return ThemeData(colorScheme: colorScheme, textTheme: themedText);
});

final darkThemeDataProvider = Provider<ThemeData>((ref) {
  final state = ref.watch(themeNotifierProvider);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: state.seedColor,
    brightness: Brightness.dark,
  );
  final baseText = GoogleFonts.rubikTextTheme();
  final themedText = baseText.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  return ThemeData(colorScheme: colorScheme, textTheme: themedText);
});
