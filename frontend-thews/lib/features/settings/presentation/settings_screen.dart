import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'settings_provider.dart';
import 'widgets/settings_sections.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppearanceSection(
            settings: settings,
            notifier: settingsNotifier,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          WeightUnitSection(
            settings: settings,
            notifier: settingsNotifier,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          DataManagementSection(isDark: isDark),
          const SizedBox(height: 24),
          AboutSection(isDark: isDark),
        ],
      ),
    );
  }
}
