import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/weight_unit.dart';
import '../domain/app_settings.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main()');
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  static const String _keyThemeMode = 'theme_mode';
  static const String _keyWeightUnit = 'weight_unit';
  static const String _keyWeeklyGoal = 'weekly_goal';
  static const String _keyDailyCountingMode = 'daily_counting_mode';
  static const String _keyAutoStartRestTimer = 'auto_start_rest_timer';
  static const String _keyDefaultRestDuration = 'default_rest_duration';

  SettingsNotifier(this._prefs) : super(const AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final themeStr = _prefs.getString(_keyThemeMode) ?? 'dark';
    final themeMode = _themeModeFromString(themeStr);

    final unitStr = _prefs.getString(_keyWeightUnit) ?? 'kg';
    final weightUnit = WeightUnit.fromString(unitStr);

    final weeklyGoal = _prefs.getInt(_keyWeeklyGoal) ?? 4;

    final modeStr = _prefs.getString(_keyDailyCountingMode) ?? 'individually';
    final dailyCountingMode = modeStr == 'groupedByDay'
        ? DailyWorkoutCountingMode.groupedByDay
        : DailyWorkoutCountingMode.individually;

    bool autoStart = true;
    try {
      final rawAutoStart = _prefs.get(_keyAutoStartRestTimer);
      if (rawAutoStart is bool) {
        autoStart = rawAutoStart;
      } else if (rawAutoStart is String) {
        autoStart = rawAutoStart.toLowerCase() == 'true';
      }
    } catch (_) {
      autoStart = true;
    }

    int restDuration = 90;
    try {
      final rawDuration = _prefs.get(_keyDefaultRestDuration);
      if (rawDuration is int) {
        restDuration = rawDuration;
      } else if (rawDuration is String) {
        restDuration = int.tryParse(rawDuration) ?? 90;
      }
    } catch (_) {
      restDuration = 90;
    }

    state = AppSettings(
      themeMode: themeMode,
      weightUnit: weightUnit,
      weeklyGoal: weeklyGoal,
      dailyCountingMode: dailyCountingMode,
      autoStartRestTimer: autoStart,
      defaultRestDuration: restDuration,
    );
  }

  ThemeMode _themeModeFromString(String val) {
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_keyThemeMode, _themeModeToString(mode));
  }

  Future<void> toggleTheme() async {
    final newMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    state = state.copyWith(weightUnit: unit);
    await _prefs.setString(_keyWeightUnit, unit.label);
  }

  Future<void> setWeeklyGoal(int goal) async {
    if (goal < 1 || goal > 7) return;
    state = state.copyWith(weeklyGoal: goal);
    await _prefs.setInt(_keyWeeklyGoal, goal);
  }

  Future<void> setDailyCountingMode(DailyWorkoutCountingMode mode) async {
    state = state.copyWith(dailyCountingMode: mode);
    await _prefs.setString(_keyDailyCountingMode, mode.name);
  }

  Future<void> setAutoStartRestTimer(bool enabled) async {
    state = state.copyWith(autoStartRestTimer: enabled);
    await _prefs.setBool(_keyAutoStartRestTimer, enabled);
  }

  Future<void> setDefaultRestDuration(int seconds) async {
    state = state.copyWith(defaultRestDuration: seconds);
    await _prefs.setInt(_keyDefaultRestDuration, seconds);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
