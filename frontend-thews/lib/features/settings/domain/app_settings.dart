import 'package:flutter/material.dart';
import '../../../core/models/weight_unit.dart';

enum DailyWorkoutCountingMode {
  individually,
  groupedByDay;

  String get label {
    switch (this) {
      case DailyWorkoutCountingMode.individually:
        return 'Count Individually';
      case DailyWorkoutCountingMode.groupedByDay:
        return 'Consider as 1 per Day';
    }
  }

  String get description {
    switch (this) {
      case DailyWorkoutCountingMode.individually:
        return 'Each workout session counts separately towards goals.';
      case DailyWorkoutCountingMode.groupedByDay:
        return 'All workouts logged on the same date count as 1 workout day.';
    }
  }
}

class AppSettings {
  final ThemeMode themeMode;
  final WeightUnit weightUnit;
  final int weeklyGoal;
  final DailyWorkoutCountingMode dailyCountingMode;
  final bool autoStartRestTimer;
  final int defaultRestDuration;
  final double? manualStrideLengthMeters;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.weightUnit = WeightUnit.kg,
    this.weeklyGoal = 4,
    this.dailyCountingMode = DailyWorkoutCountingMode.individually,
    this.autoStartRestTimer = true,
    this.defaultRestDuration = 90,
    this.manualStrideLengthMeters,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    WeightUnit? weightUnit,
    int? weeklyGoal,
    DailyWorkoutCountingMode? dailyCountingMode,
    bool? autoStartRestTimer,
    int? defaultRestDuration,
    double? manualStrideLengthMeters,
    bool clearManualStrideLength = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      weightUnit: weightUnit ?? this.weightUnit,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      dailyCountingMode: dailyCountingMode ?? this.dailyCountingMode,
      autoStartRestTimer: autoStartRestTimer ?? this.autoStartRestTimer,
      defaultRestDuration: defaultRestDuration ?? this.defaultRestDuration,
      manualStrideLengthMeters: clearManualStrideLength
          ? null
          : (manualStrideLengthMeters ?? this.manualStrideLengthMeters),
    );
  }
}
