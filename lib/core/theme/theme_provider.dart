import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/presentation/settings_provider.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final settingsNotifier = ref.watch(settingsProvider.notifier);
  final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
  return ThemeNotifier(settingsNotifier, themeMode);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SettingsNotifier _settingsNotifier;

  ThemeNotifier(this._settingsNotifier, ThemeMode initialMode)
    : super(initialMode);

  void toggleTheme() {
    _settingsNotifier.toggleTheme();
  }

  void setThemeMode(ThemeMode mode) {
    _settingsNotifier.setThemeMode(mode);
  }
}
