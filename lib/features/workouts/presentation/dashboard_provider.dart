import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_provider.dart';

class DashboardStats {
  final int workoutsThisWeek;
  final int weeklyGoal;
  final double totalVolume;
  final int streakDays;
  final List<WorkoutData> recentWorkouts;

  const DashboardStats({
    required this.workoutsThisWeek,
    required this.weeklyGoal,
    required this.totalVolume,
    required this.streakDays,
    required this.recentWorkouts,
  });
}

final totalVolumeStreamProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTotalVolume();
});

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final workoutsAsync = ref.watch(allWorkoutsStreamProvider);
  final volumeAsync = ref.watch(totalVolumeStreamProvider);
  final settings = ref.watch(settingsProvider);

  if (workoutsAsync is AsyncLoading || volumeAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (workoutsAsync.hasError) {
    return AsyncValue.error(
      workoutsAsync.error!,
      workoutsAsync.stackTrace ?? StackTrace.current,
    );
  }

  if (volumeAsync.hasError) {
    return AsyncValue.error(
      volumeAsync.error!,
      volumeAsync.stackTrace ?? StackTrace.current,
    );
  }

  final workouts = workoutsAsync.value ?? [];
  final totalVolume = volumeAsync.value ?? 0.0;

  final now = DateTime.now();
  // Compute start of week (Monday)
  final mondayOfThisWeek = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final sundayOfThisWeek = mondayOfThisWeek.add(
    const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
  );

  final workoutsThisWeekList = workouts.where((w) {
    return w.date.isAfter(
          mondayOfThisWeek.subtract(const Duration(seconds: 1)),
        ) &&
        w.date.isBefore(sundayOfThisWeek);
  }).toList();

  int workoutsThisWeekCount = 0;
  if (settings.dailyCountingMode == DailyWorkoutCountingMode.groupedByDay) {
    final uniqueDays = workoutsThisWeekList
        .map((w) => '${w.date.year}-${w.date.month}-${w.date.day}')
        .toSet();
    workoutsThisWeekCount = uniqueDays.length;
  } else {
    workoutsThisWeekCount = workoutsThisWeekList.length;
  }

  // Compute streak
  final streak = _calculateStreak(workouts, settings.dailyCountingMode);

  return AsyncValue.data(
    DashboardStats(
      workoutsThisWeek: workoutsThisWeekCount,
      weeklyGoal: settings.weeklyGoal,
      totalVolume: totalVolume,
      streakDays: streak,
      recentWorkouts: workouts.take(4).toList(),
    ),
  );
});

final allWorkoutsStreamProvider = StreamProvider<List<WorkoutData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllWorkouts();
});

int _calculateStreak(
  List<WorkoutData> workouts,
  DailyWorkoutCountingMode mode,
) {
  if (workouts.isEmpty) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final workoutDates =
      workouts
          .map((w) => DateTime(w.date.year, w.date.month, w.date.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  if (workoutDates.isEmpty) return 0;

  int streak = 0;
  DateTime checkDate = today;

  // If no workout today, check if yesterday had a workout to maintain streak
  if (!workoutDates.contains(today)) {
    checkDate = today.subtract(const Duration(days: 1));
    if (!workoutDates.contains(checkDate)) {
      return 0;
    }
  }

  while (workoutDates.contains(checkDate)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }

  return streak;
}
