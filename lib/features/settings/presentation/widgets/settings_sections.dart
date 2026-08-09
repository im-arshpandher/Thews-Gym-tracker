import '../../../../core/models/weight_unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/backup_export_service.dart';
import '../../domain/app_settings.dart';
import '../settings_provider.dart';

class AppearanceSection extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  final bool isDark;

  const AppearanceSection({
    super.key,
    required this.settings,
    required this.notifier,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'APPEARANCE',
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        settings.themeMode == ThemeMode.dark
                            ? Icons.dark_mode
                            : (settings.themeMode == ThemeMode.light
                                  ? Icons.light_mode
                                  : Icons.brightness_auto),
                        color: isDark
                            ? AppColors.primaryVoltDim
                            : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Theme',
                              style: AppTypography.bodyLg(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Theme setting is saved and persistent',
                              style: AppTypography.bodySm(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 18),
                          label: Text('Dark', maxLines: 1, softWrap: false),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 18),
                          label: Text('Light', maxLines: 1, softWrap: false),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_suggest, size: 18),
                          label: Text('System', maxLines: 1, softWrap: false),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        notifier.setThemeMode(newSelection.first);
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimaryContainer,
                        selectedForegroundColor: isDark
                            ? AppColors.primaryVoltOn
                            : AppColors.lightPrimaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Workout Goals & Tracking Section (Req 6 & Req 7)
          Text(
            'WORKOUT GOALS & TRACKING',
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Weekly Goal Setting (Req 6)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Icon(
                Icons.flag,
                color: isDark
                    ? AppColors.primaryVoltDim
                    : AppColors.lightPrimary,
              ),
              title: Text(
                'Weekly Workout Goal',
                style: AppTypography.bodyLg(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                '${settings.weeklyGoal} workouts targeted per week',
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                    onPressed: settings.weeklyGoal > 1
                        ? () => notifier.setWeeklyGoal(
                            settings.weeklyGoal - 1,
                          )
                        : null,
                  ),
                  Text(
                    '${settings.weeklyGoal}',
                    style: AppTypography.headlineSm(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                    onPressed: settings.weeklyGoal < 7
                        ? () => notifier.setWeeklyGoal(
                            settings.weeklyGoal + 1,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Daily Workout Counting Mode Setting (Req 7)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: isDark
                            ? AppColors.primaryVoltDim
                            : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Same-Day Workout Calculation',
                              style: AppTypography.bodyLg(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              settings.dailyCountingMode.description,
                              style: AppTypography.bodySm(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<DailyWorkoutCountingMode>(
                    segments: const [
                      ButtonSegment<DailyWorkoutCountingMode>(
                        value: DailyWorkoutCountingMode.individually,
                        icon: Icon(Icons.fitness_center, size: 18),
                        label: Text(
                          'Individually',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment<DailyWorkoutCountingMode>(
                        value: DailyWorkoutCountingMode.groupedByDay,
                        icon: Icon(Icons.today, size: 18),
                        label: Text('1 per Day', maxLines: 1, softWrap: false),
                      ),
                    ],
                    selected: {settings.dailyCountingMode},
                    onSelectionChanged:
                        (Set<DailyWorkoutCountingMode> newSelection) {
                          notifier.setDailyCountingMode(
                            newSelection.first,
                          );
                        },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimaryContainer,
                      selectedForegroundColor: isDark
                          ? AppColors.primaryVoltOn
                          : AppColors.lightPrimaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Unit Section

      ],
    );
  }
}

class WeightUnitSection extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  final bool isDark;

  const WeightUnitSection({
    super.key,
    required this.settings,
    required this.notifier,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'PREFERENCES',
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.scale,
                color: isDark
                    ? AppColors.primaryVoltDim
                    : AppColors.lightPrimary,
              ),
              title: Text(
                'Weight Unit',
                style: AppTypography.bodyLg(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              trailing: DropdownButton<WeightUnit>(
                value: settings.weightUnit,
                underline: const SizedBox(),
                dropdownColor: isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.lightSurfaceContainerLow,
                items: WeightUnit.values.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text(
                      u.label.toUpperCase(),
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newUnit) {
                  if (newUnit != null) {
                    notifier.setWeightUnit(newUnit);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Data Management & Backup Section (Phase 4.1)

      ],
    );
  }
}

class DataManagementSection extends ConsumerWidget {
  final bool isDark;

  const DataManagementSection({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'DATA MANAGEMENT & BACKUP',
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.download,
                      color: isDark
                          ? AppColors.primaryVoltDim
                          : AppColors.lightPrimary,
                    ),
                    title: const Text('Export JSON Backup'),
                    subtitle: const Text(
                      'Full database backup of exercises, routines, and workout logs',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share Backup File',
                      onPressed: () async {
                        final service = BackupExportService(
                          ref.read(databaseProvider),
                        );
                        try {
                          await service.shareBackupJson();
                        } catch (_) {
                          final jsonStr = await service.exportBackupJson();
                          await Clipboard.setData(ClipboardData(text: jsonStr));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'JSON Backup copied to clipboard!',
                                ),
                                backgroundColor: AppColors.primaryVolt,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    onTap: () async {
                      final service = BackupExportService(
                        ref.read(databaseProvider),
                      );
                      final jsonStr = await service.exportBackupJson();
                      await Clipboard.setData(ClipboardData(text: jsonStr));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('JSON Backup copied to clipboard!'),
                            backgroundColor: AppColors.primaryVolt,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.table_chart,
                      color: isDark
                          ? AppColors.primaryVoltDim
                          : AppColors.lightPrimary,
                    ),
                    title: const Text('Export CSV Log History'),
                    subtitle: const Text(
                      'Export logs in CSV format (compatible with Strong/Hevy)',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share CSV File',
                      onPressed: () async {
                        final service = BackupExportService(
                          ref.read(databaseProvider),
                        );
                        try {
                          await service.shareWorkoutsCsv();
                        } catch (_) {
                          final csvStr = await service.exportWorkoutsCsv();
                          await Clipboard.setData(ClipboardData(text: csvStr));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'CSV Workout Log copied to clipboard!',
                                ),
                                backgroundColor: AppColors.primaryVolt,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    onTap: () async {
                      final service = BackupExportService(
                        ref.read(databaseProvider),
                      );
                      final csvStr = await service.exportWorkoutsCsv();
                      await Clipboard.setData(ClipboardData(text: csvStr));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'CSV Workout Log copied to clipboard!',
                            ),
                            backgroundColor: AppColors.primaryVolt,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.upload,
                      color: isDark
                          ? AppColors.primaryVoltDim
                          : AppColors.lightPrimary,
                    ),
                    title: const Text('Restore Data from Backup'),
                    subtitle: const Text(
                      'Pick JSON backup file or paste content to restore',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.folder_open),
                      tooltip: 'Pick File to Restore',
                      onPressed: () async {
                        final service = BackupExportService(
                          ref.read(databaseProvider),
                        );
                        try {
                          final count = await service.importBackupFromFile();
                          if (count != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Restored $count workouts from backup file!',
                                ),
                                backgroundColor: AppColors.primaryVolt,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error restoring file: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    onTap: () {
                      final controller = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Restore JSON Backup'),
                          content: TextField(
                            controller: controller,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              hintText: 'Paste backup JSON string here...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'CANCEL',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final text = controller.text.trim();
                                if (text.isNotEmpty) {
                                  final service = BackupExportService(
                                    ref.read(databaseProvider),
                                  );
                                  try {
                                    final count = await service
                                        .restoreBackupJson(text);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Restored $count workouts from backup!',
                                          ),
                                          backgroundColor:
                                              AppColors.primaryVolt,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error restoring backup: $e',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              child: const Text(
                                'RESTORE NOW',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.cleaning_services_outlined,
                      color: AppColors.error,
                    ),
                    title: const Text('Reset & Re-seed Exercise Library'),
                    subtitle: const Text(
                      'Wipe old exercises and build fresh exercise library from scratch with new metric configs',
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Reset Exercise Library?'),
                            content: const Text(
                              'This will permanently delete all custom & old exercises, routines, and workout history, and seed the new exercise library from scratch.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('CANCEL'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final db = ref.read(databaseProvider);
                                  await db.resetAndSeedExerciseLibrary();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Exercise library re-seeded from scratch!',
                                        ),
                                        backgroundColor: AppColors.primaryVolt,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('RE-SEED NOW'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text(
                        'RE-SEED',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.refresh_outlined,
                      color: AppColors.error,
                    ),
                    title: const Text('Reset & Seed This Week\'s Workouts'),
                    subtitle: const Text(
                      'Clear existing workout history and load tuned sample workout sessions for this week',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Reset All Workout Data?'),
                            content: const Text(
                              'This action will delete all existing workout history and insert 4 freshly tuned workout sessions for this week.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('CANCEL'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final db = ref.read(databaseProvider);
                                  await db.clearAndSeedThisWeekWorkouts();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Seeded 4 sample workouts for this week!',
                                        ),
                                        backgroundColor: AppColors.primaryVolt,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('RESET & SEED'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text(
                        'RESET LOGS',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}

class AboutSection extends StatelessWidget {
  final bool isDark;

  const AboutSection({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'ABOUT',
            style: AppTypography.labelCaps(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: isDark
                    ? AppColors.primaryVoltDim
                    : AppColors.lightPrimary,
              ),
              title: Text(
                'Thews Workout Tracker',
                style: AppTypography.bodyLg(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                'v1.0.0 â€¢ Local-First SQLite Modular Monolith',
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
      );
  }
}
