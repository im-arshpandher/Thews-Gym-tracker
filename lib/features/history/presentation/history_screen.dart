import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'history_settings_provider.dart';
import 'widgets/workout_details_sheet.dart';

enum HistoryViewMode {
  list,
  calendar,
  grouped;

  String get label {
    switch (this) {
      case HistoryViewMode.list:
        return 'List';
      case HistoryViewMode.calendar:
        return 'Calendar';
      case HistoryViewMode.grouped:
        return 'Grouped';
    }
  }

  IconData get icon {
    switch (this) {
      case HistoryViewMode.list:
        return Icons.view_list;
      case HistoryViewMode.calendar:
        return Icons.calendar_month;
      case HistoryViewMode.grouped:
        return Icons.grid_view;
    }
  }
}

enum HistoryGroupPeriod {
  date,
  month;

  String get label {
    switch (this) {
      case HistoryGroupPeriod.date:
        return 'Date';
      case HistoryGroupPeriod.month:
        return 'Month';
    }
  }

  IconData get icon {
    switch (this) {
      case HistoryGroupPeriod.date:
        return Icons.today;
      case HistoryGroupPeriod.month:
        return Icons.calendar_view_month;
    }
  }
}

enum HistoryMenuOption { list, calendar, groupByMonth, groupByDate }

final workoutHistoryStreamProvider = StreamProvider<List<WorkoutData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllWorkouts();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _selectedCalendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _selectedCalendarDay;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '${hrs}h ${remMins}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(workoutDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyAsync = ref.watch(workoutHistoryStreamProvider);
    final historySettings = ref.watch(historySettingsProvider);
    final historyNotifier = ref.read(historySettingsProvider.notifier);

    IconData getActiveIcon() {
      if (historySettings.viewMode == HistoryViewMode.grouped) {
        return historySettings.groupPeriod == HistoryGroupPeriod.month
            ? Icons.calendar_view_month
            : Icons.today;
      }
      return historySettings.viewMode.icon;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'WORKOUT HISTORY',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<HistoryMenuOption>(
              icon: Icon(
                getActiveIcon(),
                color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
              ),
              tooltip: 'Switch View Mode',
              onSelected: (option) {
                switch (option) {
                  case HistoryMenuOption.list:
                    historyNotifier.setViewMode(HistoryViewMode.list);
                    break;
                  case HistoryMenuOption.calendar:
                    historyNotifier.setViewMode(HistoryViewMode.calendar);
                    break;
                  case HistoryMenuOption.groupByMonth:
                    historyNotifier.setGroupedWithPeriod(
                      HistoryGroupPeriod.month,
                    );
                    break;
                  case HistoryMenuOption.groupByDate:
                    historyNotifier.setGroupedWithPeriod(
                      HistoryGroupPeriod.date,
                    );
                    break;
                }
              },
              itemBuilder: (context) {
                final isGroupedMonth =
                    historySettings.viewMode == HistoryViewMode.grouped &&
                    historySettings.groupPeriod == HistoryGroupPeriod.month;
                final isGroupedDate =
                    historySettings.viewMode == HistoryViewMode.grouped &&
                    historySettings.groupPeriod == HistoryGroupPeriod.date;

                return [
                  PopupMenuItem<HistoryMenuOption>(
                    value: HistoryMenuOption.list,
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_list,
                          color:
                              historySettings.viewMode == HistoryViewMode.list
                              ? (isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary)
                              : null,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text('List View', style: AppTypography.bodyLg()),
                      ],
                    ),
                  ),
                  PopupMenuItem<HistoryMenuOption>(
                    value: HistoryMenuOption.calendar,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color:
                              historySettings.viewMode ==
                                  HistoryViewMode.calendar
                              ? (isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary)
                              : null,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text('Calendar View', style: AppTypography.bodyLg()),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<HistoryMenuOption>(
                    value: HistoryMenuOption.groupByMonth,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_view_month,
                          color: isGroupedMonth
                              ? (isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary)
                              : null,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Group by Month',
                            style: AppTypography.bodyLg(),
                          ),
                        ),
                        if (isGroupedMonth)
                          Icon(
                            Icons.check,
                            color: isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuItem<HistoryMenuOption>(
                    value: HistoryMenuOption.groupByDate,
                    child: Row(
                      children: [
                        Icon(
                          Icons.today,
                          color: isGroupedDate
                              ? (isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary)
                              : null,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Group by Date',
                            style: AppTypography.bodyLg(),
                          ),
                        ),
                        if (isGroupedDate)
                          Icon(
                            Icons.check,
                            color: isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryVolt),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error loading history: $err',
            style: AppTypography.bodyMd(color: AppColors.error),
          ),
        ),
        data: (workouts) {
          if (workouts.isEmpty) {
            return _buildEmptyState(isDark);
          }

          switch (historySettings.viewMode) {
            case HistoryViewMode.list:
              return _buildListView(workouts, isDark);
            case HistoryViewMode.calendar:
              return _buildCalendarView(workouts, isDark);
            case HistoryViewMode.grouped:
              return _buildGroupedView(
                workouts,
                historySettings.groupPeriod,
                isDark,
              );
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Workout Sessions Logged',
            style: AppTypography.headlineSm(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your first workout from the Log or Home tab!',
            style: AppTypography.bodySm(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. LIST VIEW ---
  Widget _buildListView(List<WorkoutData> workouts, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return _buildWorkoutCard(workout, isDark);
      },
    );
  }

  Widget _buildWorkoutCard(WorkoutData workout, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => WorkoutDetailsSheet.show(context, workout),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryVolt.withValues(alpha: 0.15)
                      : AppColors.lightPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: isDark
                      ? AppColors.primaryVoltDim
                      : AppColors.lightPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.notes ?? 'Workout Session',
                      style: AppTypography.bodyLg(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(workout.date)} • ${_formatDuration(workout.durationSeconds)}',
                      style: AppTypography.bodySm(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete Workout',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Workout?'),
                      content: const Text(
                        'This workout entry will be permanently removed.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'DELETE',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final db = ref.read(databaseProvider);
                    await db.deleteWorkout(workout.id);
                  }
                },
              ),
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.lightOutlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. CALENDAR VIEW ---
  Widget _buildCalendarView(List<WorkoutData> workouts, bool isDark) {
    final workoutDateSet = workouts
        .map((w) => DateTime(w.date.year, w.date.month, w.date.day))
        .toSet();

    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month,
    );
    final firstDayOfMonth = DateTime(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month,
      1,
    );
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    List<WorkoutData> filteredWorkouts = workouts;
    if (_selectedCalendarDay != null) {
      filteredWorkouts = workouts.where((w) {
        final d = w.date;
        return d.year == _selectedCalendarDay!.year &&
            d.month == _selectedCalendarDay!.month &&
            d.day == _selectedCalendarDay!.day;
      }).toList();
    }

    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Month Selector Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _selectedCalendarMonth = DateTime(
                              _selectedCalendarMonth.year,
                              _selectedCalendarMonth.month - 1,
                            );
                            _selectedCalendarDay = null;
                          });
                        },
                      ),
                      Text(
                        '${monthNames[_selectedCalendarMonth.month - 1]} ${_selectedCalendarMonth.year}',
                        style: AppTypography.headlineSm(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _selectedCalendarMonth = DateTime(
                              _selectedCalendarMonth.year,
                              _selectedCalendarMonth.month + 1,
                            );
                            _selectedCalendarDay = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weekday Header Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Text('M', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('T', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('W', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('T', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('F', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('S', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('S', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Calendar Days Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (firstWeekday - 1) + daysInMonth,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemBuilder: (context, index) {
                      if (index < firstWeekday - 1) {
                        return const SizedBox();
                      }

                      final dayNumber = index - (firstWeekday - 1) + 1;
                      final currentDate = DateTime(
                        _selectedCalendarMonth.year,
                        _selectedCalendarMonth.month,
                        dayNumber,
                      );
                      final hasWorkout = workoutDateSet.contains(currentDate);
                      final isSelected =
                          _selectedCalendarDay != null &&
                          _selectedCalendarDay!.year == currentDate.year &&
                          _selectedCalendarDay!.month == currentDate.month &&
                          _selectedCalendarDay!.day == currentDate.day;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCalendarDay = null;
                            } else {
                              _selectedCalendarDay = currentDate;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary)
                                : (hasWorkout
                                      ? (isDark
                                            ? AppColors.primaryVolt.withValues(
                                                alpha: 0.25,
                                              )
                                            : AppColors.lightPrimary.withValues(
                                                alpha: 0.14,
                                              ))
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark
                                        ? AppColors.primaryVolt
                                        : AppColors.lightPrimary)
                                  : (hasWorkout
                                        ? (isDark
                                              ? AppColors.primaryVoltDim
                                              : AppColors.lightPrimary)
                                        : Colors.transparent),
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  fontWeight: hasWorkout
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? (isDark
                                            ? AppColors.primaryVoltOn
                                            : Colors.white)
                                      : (hasWorkout
                                            ? (isDark
                                                  ? AppColors.primaryVoltDim
                                                  : AppColors.lightPrimary)
                                            : (isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors
                                                        .lightTextPrimary)),
                                ),
                              ),
                              if (hasWorkout && !isSelected)
                                Positioned(
                                  bottom: 4,
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Filter Banner if selected
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCalendarDay != null
                    ? 'Workouts on ${_selectedCalendarDay!.day}/${_selectedCalendarDay!.month}/${_selectedCalendarDay!.year}'
                    : 'Workouts for ${monthNames[_selectedCalendarMonth.month - 1]}',
                style: AppTypography.headlineSm(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              if (_selectedCalendarDay != null)
                TextButton(
                  onPressed: () => setState(() => _selectedCalendarDay = null),
                  child: const Text('Show All'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredWorkouts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No workouts recorded on this date.',
                  style: AppTypography.bodySm(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            ...filteredWorkouts.map((w) => _buildWorkoutCard(w, isDark)),
        ],
      ),
    );
  }

  // --- 3. GROUPED VIEW (By Date or Month) ---
  Widget _buildGroupedView(
    List<WorkoutData> workouts,
    HistoryGroupPeriod groupPeriod,
    bool isDark,
  ) {
    final Map<String, List<WorkoutData>> groups = {};

    if (groupPeriod == HistoryGroupPeriod.month) {
      // Group workouts by Month & Year
      for (final w in workouts) {
        final key = '${_getMonthName(w.date.month)} ${w.date.year}';
        groups.putIfAbsent(key, () => []).add(w);
      }
    } else {
      // Group workouts by Date / Day
      for (final w in workouts) {
        final key = _formatDateHeader(w.date);
        groups.putIfAbsent(key, () => []).add(w);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: groups.entries.map((entry) {
        final groupTitle = entry.key;
        final groupWorkouts = entry.value;
        final totalDuration = groupWorkouts.fold<int>(
          0,
          (sum, w) => sum + w.durationSeconds,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            initiallyExpanded: true,
            leading: Icon(
              groupPeriod == HistoryGroupPeriod.month
                  ? Icons.collections_bookmark
                  : Icons.event_note,
              color: isDark ? AppColors.primaryVoltDim : AppColors.lightPrimary,
            ),
            title: Text(
              groupTitle.toUpperCase(),
              style: AppTypography.headlineSm(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              '${groupWorkouts.length} Workout${groupWorkouts.length == 1 ? '' : 's'} • Total Time: ${_formatDuration(totalDuration)}',
              style: AppTypography.bodySm(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            children: groupWorkouts
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: _buildWorkoutCard(w, isDark),
                  ),
                )
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(workoutDay).inDays;

    final monthName = _getMonthName(date.month);
    if (diff == 0) return 'Today • ${date.day} $monthName ${date.year}';
    if (diff == 1) return 'Yesterday • ${date.day} $monthName ${date.year}';
    return '${date.day} $monthName ${date.year}';
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month - 1];
  }
}
