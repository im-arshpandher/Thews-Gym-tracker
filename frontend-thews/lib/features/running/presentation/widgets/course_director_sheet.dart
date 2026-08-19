import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/course_storage_service.dart';
import '../../../../core/services/turn_navigation_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/gpx_course_navigator.dart';

/// Modal bottom sheet for Course Director: browsing courses, importing GPX files, and launching turn-by-turn navigation.
class CourseDirectorSheet extends ConsumerStatefulWidget {
  const CourseDirectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CourseDirectorSheet(),
    );
  }

  @override
  ConsumerState<CourseDirectorSheet> createState() => _CourseDirectorSheetState();
}

class _CourseDirectorSheetState extends ConsumerState<CourseDirectorSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  CourseRoute? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCourses = ref.watch(courseDirectorProvider);
    final navState = ref.watch(turnNavigationProvider);
    final navNotifier = ref.read(turnNavigationProvider.notifier);

    final presetCourses = allCourses.where((c) => c.source == 'preset').toList();
    final customCourses = allCourses.where((c) => c.source != 'preset').toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.lightSurfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Grab Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkOutlineVariant.withValues(alpha: 0.6)
                    : AppColors.lightOutlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.chestAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: AppColors.chestAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course Director & GPX',
                        style: AppTypography.cardTitle(
                          color: isDark ? Colors.white : Colors.black87,
                        ).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      Text(
                        'Turn-by-turn guided outdoor navigation',
                        style: AppTypography.bodySm(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 3. Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.lightSurfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.chestAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.black,
                unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                labelStyle: AppTypography.bodyMd().copyWith(fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Text(
                      'Curated Loops (${presetCourses.length})',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  Tab(
                    child: Text(
                      'My GPX / Imported (${customCourses.length})',
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 4. Tab Views
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Preset Curated Courses
                _buildCourseList(
                  courses: presetCourses,
                  isDark: isDark,
                  activeNavCourseId: navState.activeCourse?.id,
                  onSelect: (course) => setState(() => _selectedCourse = course),
                  onStartNav: (course) {
                    HapticFeedback.mediumImpact();
                    navNotifier.startCourse(course);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.navigation_rounded, color: AppColors.chestAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Navigating: ${course.name}',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                // Tab 2: Custom / Imported GPX Courses
                _buildCustomGpxTab(
                  courses: customCourses,
                  isDark: isDark,
                  activeNavCourseId: navState.activeCourse?.id,
                  onSelect: (course) => setState(() => _selectedCourse = course),
                  onStartNav: (course) {
                    HapticFeedback.mediumImpact();
                    navNotifier.startCourse(course);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          // 5. Active Navigation Floating Bottom Actions
          if (navState.isNavigating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHighest
                    : AppColors.lightSurfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.near_me_rounded, color: AppColors.chestAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Navigating: ${navState.activeCourse?.name ?? 'Active Course'}',
                      style: AppTypography.bodyMd(
                        color: isDark ? Colors.white : Colors.black87,
                      ).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('End Nav', maxLines: 1, softWrap: false),
                    onPressed: () {
                      navNotifier.stopCourse();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseList({
    required List<CourseRoute> courses,
    required bool isDark,
    required String? activeNavCourseId,
    required ValueChanged<CourseRoute> onSelect,
    required ValueChanged<CourseRoute> onStartNav,
  }) {
    if (courses.isEmpty) {
      return Center(
        child: Text(
          'No courses available',
          style: AppTypography.bodyMd(color: Colors.grey),
          maxLines: 1,
          softWrap: false,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        final isSelected = _selectedCourse?.id == course.id;
        final isNavigatingThis = activeNavCourseId == course.id;

        return _buildCourseCard(
          course: course,
          isDark: isDark,
          isSelected: isSelected,
          isNavigatingThis: isNavigatingThis,
          onTap: () => onSelect(course),
          onStart: () => onStartNav(course),
        );
      },
    );
  }

  Widget _buildCustomGpxTab({
    required List<CourseRoute> courses,
    required bool isDark,
    required String? activeNavCourseId,
    required ValueChanged<CourseRoute> onSelect,
    required ValueChanged<CourseRoute> onStartNav,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      children: [
        // Import GPX Button
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.file_upload_outlined, size: 20),
          label: const Text(
            'Import GPX File from Storage',
            maxLines: 1,
            softWrap: false,
          ),
          onPressed: () async {
            final imported = await ref
                .read(courseDirectorProvider.notifier)
                .importGpxFile();
            if (imported != null && mounted) {
              setState(() => _selectedCourse = imported);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Imported "${imported.name}" with ${imported.turnCues.length} turn cues',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),

        const SizedBox(height: 12),

        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                ),
                const SizedBox(height: 12),
                Text(
                  'No custom GPX courses imported yet',
                  style: AppTypography.bodyLg(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap above to load any .gpx track from Strava, Garmin, or Komoot',
                  style: AppTypography.bodySm(
                    color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...courses.map((course) {
            final isSelected = _selectedCourse?.id == course.id;
            final isNavigatingThis = activeNavCourseId == course.id;

            return _buildCourseCard(
              course: course,
              isDark: isDark,
              isSelected: isSelected,
              isNavigatingThis: isNavigatingThis,
              onTap: () => onSelect(course),
              onStart: () => onStartNav(course),
              onDelete: () async {
                await ref
                    .read(courseDirectorProvider.notifier)
                    .deleteCourse(course.id);
                if (_selectedCourse?.id == course.id) {
                  setState(() => _selectedCourse = null);
                }
              },
              onExport: () => ref
                  .read(courseDirectorProvider.notifier)
                  .exportGpx(course),
            );
          }),
      ],
    );
  }

  Widget _buildCourseCard({
    required CourseRoute course,
    required bool isDark,
    required bool isSelected,
    required bool isNavigatingThis,
    required VoidCallback onTap,
    required VoidCallback onStart,
    VoidCallback? onDelete,
    VoidCallback? onExport,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isNavigatingThis
            ? (isDark ? const Color(0xFF1B3828) : const Color(0xFFE8F8EE))
            : (isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurfaceContainerHigh),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNavigatingThis
              ? Colors.green
              : (isSelected
                  ? AppColors.chestAccent
                  : (isDark
                      ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
                      : AppColors.lightOutlineVariant)),
          width: isNavigatingThis || isSelected ? 1.8 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Title & Badges Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.chestAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        course.isClosedLoop
                            ? Icons.loop_rounded
                            : Icons.timeline_rounded,
                        color: AppColors.chestAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.name,
                            style: AppTypography.bodyLg(
                              color: isDark ? Colors.white : Colors.black87,
                            ).copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            course.description.isNotEmpty
                                ? course.description
                                : '${course.turnCues.length} turn cues generated',
                            style: AppTypography.tinyLabel(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isNavigatingThis)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Metrics Row: Distance, Elevation, Turns
                Row(
                  children: [
                    _buildMetricChip(
                      icon: Icons.straighten_rounded,
                      label: course.formattedDistance,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      icon: Icons.trending_up_rounded,
                      label: '${course.elevationGainMeters.toInt()}m gain',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      icon: Icons.directions_rounded,
                      label: '${course.turnCues.length} turns',
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Actions: Start Navigation, Export, Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onExport != null)
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Export GPX',
                        onPressed: onExport,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        tooltip: 'Delete course',
                        onPressed: onDelete,
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isNavigatingThis ? Colors.green : AppColors.chestAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(
                        isNavigatingThis
                            ? Icons.check_circle_rounded
                            : Icons.navigation_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isNavigatingThis ? 'Navigating' : 'Start Course',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      onPressed: isNavigatingThis ? null : onStart,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.6)
            : AppColors.lightSurfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.chestAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.tinyLabel().copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
