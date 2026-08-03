import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/models/muscle_group.dart';
import '../../../../core/presentation/widgets/muscle_group_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// ponytail: shrink - Single unified dialog replaces separate Create and Edit dialogs.
class ExerciseFormDialog extends ConsumerStatefulWidget {
  final ExerciseData? exercise;

  const ExerciseFormDialog({super.key, this.exercise});

  static Future<void> show(BuildContext context, {ExerciseData? exercise}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseFormDialog(exercise: exercise),
    );
  }

  @override
  ConsumerState<ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends ConsumerState<ExerciseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _videoUrlController;
  late MuscleGroup _selectedGroup;
  late Set<String> _selectedSecondaryGroups;
  bool _isSubmitting = false;

  bool get _isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name ?? '');
    _videoUrlController = TextEditingController(
      text: widget.exercise?.videoUrl ?? '',
    );
    _selectedGroup = widget.exercise != null
        ? MuscleGroup.fromString(widget.exercise!.muscleGroup)
        : MuscleGroup.chest;

    final existingSecondary = widget.exercise?.secondaryMuscleGroups;
    if (existingSecondary != null && existingSecondary.isNotEmpty) {
      _selectedSecondaryGroups = existingSecondary
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } else {
      _selectedSecondaryGroups = {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      final name = _nameController.text.trim();
      final muscleGroup = _selectedGroup.label;
      final secondaryStr = _selectedSecondaryGroups.isEmpty
          ? null
          : _selectedSecondaryGroups.join(', ');
      final videoUrl = _videoUrlController.text.trim();
      final valUrl = videoUrl.isNotEmpty ? videoUrl : null;

      if (_isEditing) {
        await (db.update(
          db.exercises,
        )..where((t) => t.id.equals(widget.exercise!.id))).write(
          ExercisesCompanion(
            name: Value(name),
            muscleGroup: Value(muscleGroup),
            secondaryMuscleGroups: Value(secondaryStr),
            videoUrl: Value(valUrl),
          ),
        );
      } else {
        await db.insertExercise(
          ExercisesCompanion.insert(
            name: name,
            muscleGroup: muscleGroup,
            secondaryMuscleGroups: Value(secondaryStr),
            isCustom: const Value(true),
            videoUrl: Value(valUrl),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? '$name updated' : '$name added to library',
              style: AppTypography.bodyMd(color: AppColors.primaryVoltOn),
            ),
            backgroundColor: AppColors.primaryVolt,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving exercise: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.lightSurfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkOutline
                              : AppColors.lightOutline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isEditing
                              ? 'EDIT EXERCISE'
                              : 'CREATE CUSTOM EXERCISE',
                          style: AppTypography.headlineSm(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EXERCISE NAME',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: AppTypography.bodyMd(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Incline Dumbbell Flyes',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an exercise name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MUSCLE GROUP',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MuscleGroup>(
                      initialValue: _selectedGroup,
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: isDark
                          ? AppColors.darkSurfaceContainerHigh
                          : AppColors.lightSurfaceContainerLowest,
                      elevation: 4,
                      icon: Icon(
                        Icons.arrow_drop_down_circle_outlined,
                        color: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary,
                        size: 20,
                      ),
                      items: MuscleGroup.values
                          .where((g) => g != MuscleGroup.all)
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Row(
                                children: [
                                  MuscleGroupIcon(
                                    muscleGroup: g.label,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    g.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGroup = val);
                      },
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SECONDARY MUSCLE TARGETS (OPTIONAL)',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MuscleGroup.values
                          .where(
                            (g) => g != MuscleGroup.all && g != _selectedGroup,
                          )
                          .map((g) {
                            final isSelected = _selectedSecondaryGroups
                                .contains(g.label);
                            return FilterChip(
                              label: Text(g.label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSecondaryGroups.add(g.label);
                                  } else {
                                    _selectedSecondaryGroups.remove(g.label);
                                  }
                                });
                              },
                              selectedColor: isDark
                                  ? AppColors.primaryVolt.withValues(alpha: 0.3)
                                  : AppColors.lightPrimaryContainer,
                              checkmarkColor: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? (isDark
                                          ? AppColors.primaryVolt
                                          : AppColors.lightPrimary)
                                    : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'VIDEO / GIF DEMO URL (OPTIONAL)',
                      style: AppTypography.labelCaps(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _videoUrlController,
                      keyboardType: TextInputType.url,
                      style: AppTypography.bodyMd(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'https://youtube.com/... or .gif link',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryVolt,
                          foregroundColor: AppColors.primaryVoltOn,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isEditing ? 'SAVE CHANGES' : 'CREATE EXERCISE',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
