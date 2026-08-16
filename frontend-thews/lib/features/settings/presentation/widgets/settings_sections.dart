import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/models/smartwatch_models.dart';
import '../../../../core/models/weight_unit.dart';
import '../../../../core/services/health_platform_service.dart';
import '../../../../core/services/smartwatch_sync_service.dart';
import '../../../../core/services/tile_cache_service.dart';
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

        // Workout Goals & Tracking Section
        Text(
          'WORKOUT GOALS & TRACKING',
          style: AppTypography.labelCaps(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Weekly Goal Setting
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
                      ? () => notifier.setWeeklyGoal(settings.weeklyGoal - 1)
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
                      ? () => notifier.setWeeklyGoal(settings.weeklyGoal + 1)
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Daily Workout Counting Mode Setting
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
                    notifier.setDailyCountingMode(newSelection.first);
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
        const SizedBox(height: 8),

        // Jog Stride Length Setting
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(
              Icons.straighten,
              color: isDark
                  ? AppColors.primaryVoltDim
                  : AppColors.lightPrimary,
            ),
            title: Text(
              'Jog Stride Length',
              style: AppTypography.bodyLg(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              settings.manualStrideLengthMeters == null
                  ? 'Auto (Dynamic based on speed)'
                  : '${(settings.manualStrideLengthMeters! * 100).toStringAsFixed(0)} cm (${settings.manualStrideLengthMeters!.toStringAsFixed(2)} m)',
              style: AppTypography.bodySm(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onTap: () => _showStrideLengthDialog(context, settings, notifier, isDark),
          ),
        ),
      ],
    );
  }

  void _showStrideLengthDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
    bool isDark,
  ) {
    final controller = TextEditingController(
      text: settings.manualStrideLengthMeters != null
          ? (settings.manualStrideLengthMeters! * 100).toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Jog Stride Length'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter custom stride length in centimeters (cm), or choose Auto to dynamically estimate based on real-time speed.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Stride Length (cm)',
                  hintText: 'e.g. 78',
                  suffixText: 'cm',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                notifier.setManualStrideLength(null);
                Navigator.of(context).pop();
              },
              child: const Text('SET TO AUTO', maxLines: 1, softWrap: false),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', maxLines: 1, softWrap: false),
            ),
            ElevatedButton(
              onPressed: () {
                final cm = int.tryParse(controller.text);
                if (cm != null && cm >= 40 && cm <= 200) {
                  notifier.setManualStrideLength(cm / 100.0);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('SAVE', maxLines: 1, softWrap: false),
            ),
          ],
        );
      },
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
    final primaryColor =
        isDark ? AppColors.primaryVolt : AppColors.lightPrimary;

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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Export JSON Backup
                _SettingsActionTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Export JSON Backup',
                  subtitle: const Text(
                      'Full database backup of exercises, routines, and workout logs'),
                  isDark: isDark,
                  actionButton: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor:
                          isDark ? AppColors.darkBackground : Colors.white,
                    ),
                    onPressed: () async {
                      final service =
                          BackupExportService(ref.read(databaseProvider));
                      try {
                        await service.shareBackupJson();
                      } catch (_) {
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
                      }
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text(
                      'EXPORT BACKUP',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Export CSV History
                _SettingsActionTile(
                  icon: Icons.table_chart_outlined,
                  title: 'Export CSV Log History',
                  subtitle: const Text(
                      'Export logs in CSV format (compatible with Strong/Hevy)'),
                  isDark: isDark,
                  actionButton: OutlinedButton.icon(
                    onPressed: () async {
                      final service =
                          BackupExportService(ref.read(databaseProvider));
                      try {
                        await service.shareWorkoutsCsv();
                      } catch (_) {
                        final csvStr = await service.exportWorkoutsCsv();
                        await Clipboard.setData(ClipboardData(text: csvStr));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('CSV Log copied to clipboard!'),
                              backgroundColor: AppColors.primaryVolt,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text(
                      'EXPORT CSV',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Restore Data
                _SettingsActionTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Restore Data from Backup',
                  subtitle: const Text(
                      'Pick JSON backup file or paste content to restore'),
                  isDark: isDark,
                  actionButton: OutlinedButton.icon(
                    onPressed: () async {
                      final service =
                          BackupExportService(ref.read(databaseProvider));
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
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text(
                      'RESTORE FILE',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Clear Offline Map Cache
                _SettingsActionTile(
                  icon: Icons.map_outlined,
                  title: 'Clear Offline Map Cache',
                  subtitle: FutureBuilder<double>(
                    future: DiskCachedTileImageProvider.getCacheSizeMegaBytes(),
                    builder: (context, snapshot) {
                      final sizeMb = (snapshot.data ?? 0.0).toStringAsFixed(1);
                      return Text('Free up storage (Current: $sizeMb MB)');
                    },
                  ),
                  isDark: isDark,
                  actionButton: OutlinedButton.icon(
                    onPressed: () async {
                      await DiskCachedTileImageProvider.clearMapCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline map tile cache cleared!'),
                            backgroundColor: AppColors.primaryVolt,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    label: const Text(
                      'CLEAR CACHE',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Reset Exercise Library
                _SettingsActionTile(
                  icon: Icons.restart_alt,
                  iconColor: AppColors.error,
                  title: 'Reset & Re-seed Library',
                  subtitle: const Text(
                      'Wipe old exercises and build fresh exercise library from scratch'),
                  isDark: isDark,
                  actionButton: ElevatedButton.icon(
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
                            'This will permanently delete all custom exercises and routines, and re-seed the standard exercise library.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL',
                                  maxLines: 1, softWrap: false),
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
                              child: const Text('RE-SEED NOW',
                                  maxLines: 1, softWrap: false),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      'RE-SEED NOW',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Reset Workout History
                _SettingsActionTile(
                  icon: Icons.delete_forever_outlined,
                  iconColor: AppColors.error,
                  title: 'Reset Workout History',
                  subtitle: const Text(
                      'Clear existing workout logs and insert 4 tuned sample sessions'),
                  isDark: isDark,
                  actionButton: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset All Workout Data?'),
                          content: const Text(
                            'This action will delete all existing workout history and insert 4 sample sessions for this week.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL',
                                  maxLines: 1, softWrap: false),
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
                              child: const Text('RESET & SEED',
                                  maxLines: 1, softWrap: false),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning, size: 18),
                    label: const Text(
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

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget subtitle;
  final Widget actionButton;
  final bool isDark;

  const _SettingsActionTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionButton,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: iconColor ??
                  (isDark ? AppColors.primaryVoltDim : AppColors.lightPrimary),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLg(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: AppTypography.bodySm(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    child: subtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: actionButton,
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
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: isDark
                      ? AppColors.primaryVoltDim
                      : AppColors.lightPrimary,
                ),
                title: Text(
                  'Thews Gym Tracker',
                  style: AppTypography.bodyLg(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'v1.0.0 • Offline-First GPS & Workout Tracker',
                  style: AppTypography.bodySm(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.workspace_premium_outlined,
                  color: isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
                ),
                title: Text(
                  'Open Source Licenses & Certificates',
                  style: AppTypography.bodyLg(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'View certificates and third-party software disclosures',
                  style: AppTypography.bodySm(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Thews Gym Tracker',
                    applicationVersion: 'v1.0.0',
                    applicationLegalese:
                        '© 2026 Thews Gym Tracker. Open Source Software Disclosures & Certificates.',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WearableHealthSection extends ConsumerWidget {
  final bool isDark;

  const WearableHealthSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchState = ref.watch(smartwatchServiceProvider);
    final watchNotifier = ref.read(smartwatchServiceProvider.notifier);
    final healthState = ref.watch(healthPlatformServiceProvider);
    final healthNotifier = ref.read(healthPlatformServiceProvider.notifier);

    final isWatchConnected =
        watchState.status == SmartwatchConnectionStatus.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WEARABLES & HEALTH PLATFORMS',
          style: AppTypography.labelCaps(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Smartwatch Companion Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.watch,
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
                            'Smartwatch Companion',
                            style: AppTypography.bodyLg(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isWatchConnected
                                ? '${watchState.device?.name} • Connected (${watchState.device?.batteryLevelPercent}% Batt)'
                                : 'Wear OS / Apple Watch bi-directional sync',
                            style: AppTypography.bodySm(
                              color: isWatchConnected
                                  ? Colors.greenAccent.shade700
                                  : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWatchConnected
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isWatchConnected ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isWatchConnected
                              ? Colors.green
                              : (isDark ? Colors.grey : Colors.black54),
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: isWatchConnected
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  watchNotifier.disconnectSmartwatch(),
                              icon: const Icon(Icons.link_off, size: 16),
                              label: const Text(
                                'Disconnect',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () =>
                                  watchNotifier.connectSmartwatch(simulated: true),
                              icon: const Icon(Icons.link, size: 16),
                              label: const Text(
                                'Connect Watch',
                                maxLines: 1,
                                softWrap: false,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryVolt,
                                foregroundColor: AppColors.primaryVoltOn,
                              ),
                            ),
                    ),
                    if (isWatchConnected) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          watchNotifier.syncWorkoutPayload(
                            const SmartwatchWorkoutPayload(
                              workoutTitle: 'Sample Push Workout',
                              currentExerciseName: 'Barbell Bench Press',
                              currentSetIndex: 1,
                              totalSets: 4,
                              targetWeightKg: 85.0,
                              targetReps: 8,
                              restTimerSecondsRemaining: 90,
                              isRestTimerActive: true,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test workout packet sent to watch!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_to_mobile, size: 16),
                        label: const Text(
                          'Test Sync',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Health Platform Integration Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.health_and_safety,
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
                            'Apple Health & Health Connect',
                            style: AppTypography.bodyLg(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Export workout calories & sync daily steps',
                            style: AppTypography.bodySm(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: healthState.isAutoSyncEnabled,
                      onChanged: (val) => healthNotifier.setAutoSyncEnabled(val),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_walk,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${healthState.dailySteps} steps today',
                          style: AppTypography.bodySm(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${healthState.restingHeartRateBpm} BPM resting',
                          style: AppTypography.bodySm(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await healthNotifier.refreshDailyBiometrics();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Daily biometrics refreshed!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text(
                          'Sync Daily Data',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showSyncLogsDialog(context, healthState.syncLogs),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text(
                        'Audit Log',
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSyncLogsDialog(BuildContext context, List<HealthSyncLog> logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Health Platform Sync History'),
        content: SizedBox(
          width: double.maxFinite,
          child: logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No sync operations recorded yet.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final log = logs[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        log.success ? Icons.check_circle : Icons.error,
                        color: log.success ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      title: Text(
                        log.message,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        log.timestamp.toLocal().toString().split('.').first,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
  }
}

