import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    : super(ThemeState(mode: ThemeMode.system, seedColor: Colors.blue));

  void setThemeMode(ThemeMode mode) => state = state.copyWith(mode: mode);
  void setSeedColor(Color color) => state = state.copyWith(seedColor: color);
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((
  ref,
) {
  return ThemeNotifier();
});

final themeDataProvider = Provider<ThemeData>((ref) {
  final state = ref.watch(themeNotifierProvider);
  return ThemeData.from(
    colorScheme: ColorScheme.fromSeed(seedColor: state.seedColor),
  );
});

final darkThemeDataProvider = Provider<ThemeData>((ref) {
  final state = ref.watch(themeNotifierProvider);
  return ThemeData.from(
    colorScheme: ColorScheme.fromSeed(
      seedColor: state.seedColor,
      brightness: Brightness.dark,
    ),
  );
});
