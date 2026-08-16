import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/create_routine_sheet.dart';
import 'widgets/preset_gallery_sheet.dart';
import 'widgets/routine_card.dart';

final routinesProvider = StreamProvider<List<RoutineData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllRoutines();
});

final routineDetailsProvider = StreamProvider.family<List<RoutineDetail>, int>((
  ref,
  routineId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchRoutineDetails(routineId);
});

class RoutinesScreen extends ConsumerWidget {
  final Function(RoutineData)? onLaunchRoutine;

  const RoutinesScreen({super.key, this.onLaunchRoutine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ROUTINE TEMPLATES',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Starter Template Gallery',
            onPressed: () => _showPresetGalleryModal(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoutineSheet(context, ref),
        backgroundColor: AppColors.primaryVolt,
        foregroundColor: AppColors.primaryVoltOn,
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'NEW ROUTINE',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.lightOutlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Workout Routines Yet',
                      style: AppTypography.headlineSm(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create custom preset templates or import from our starter template gallery!',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showPresetGalleryModal(context, ref),
                      icon: const Icon(Icons.explore),
                      label: const Text(
                        'EXPLORE STARTER GALLERY',
                        maxLines: 1,
                        softWrap: false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryVolt,
                        foregroundColor: AppColors.primaryVoltOn,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showCreateRoutineSheet(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'CREATE CUSTOM ROUTINE',
                        maxLines: 1,
                        softWrap: false,
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return RoutineCard(
                routine: routine,
                onLaunch: () {
                  if (onLaunchRoutine != null) {
                    onLaunchRoutine!(routine);
                  } else {
                    context.go('/log');
                  }
                },
                onEdit: () {
                  _showCreateRoutineSheet(
                    context,
                    ref,
                    routineToEdit: routine,
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryVolt),
        ),
        error: (e, s) => Center(child: Text('Error loading routines: ')),
      ),
    );
  }

  static void _showCreateRoutineSheet(
    BuildContext context,
    WidgetRef ref, {
    RoutineData? routineToEdit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CreateRoutineSheet(routineToEdit: routineToEdit),
    );
  }

  static void _showPresetGalleryModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PresetGallerySheet(),
    );
  }
}
