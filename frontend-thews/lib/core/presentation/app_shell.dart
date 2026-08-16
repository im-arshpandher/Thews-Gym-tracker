import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPressTime;

  void _handleBackPress(BuildContext context) {
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      _lastBackPressTime = null;
    } else {
      final now = DateTime.now();
      if (_lastBackPressTime != null &&
          now.difference(_lastBackPressTime!) < const Duration(seconds: 2)) {
        SystemNavigator.pop();
      } else {
        _lastBackPressTime = now;
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress(context);
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerLow.withValues(alpha: 0.95)
                : AppColors.lightSurfaceContainerLowest.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.darkOutline.withValues(alpha: 0.2)
                    : AppColors.lightOutline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: SafeArea(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    icon: Icons.home,
                    label: 'HOME',
                  ),
                  _buildNavItem(
                    context,
                    index: 1,
                    icon: Icons.directions_run,
                    label: 'RUN',
                  ),
                  _buildNavItem(
                    context,
                    index: 2,
                    icon: Icons.add_circle,
                    label: 'LOG',
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.history,
                    label: 'HISTORY',
                  ),
                  _buildNavItem(
                    context,
                    index: 4,
                    icon: Icons.settings,
                    label: 'SETTINGS',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = widget.navigationShell.currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: isSelected
                  ? BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? AppColors.primaryGlow
                              : AppColors.lightPrimary.withValues(alpha: 0.18),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                icon,
                color: isSelected
                    ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  AppTypography.labelCaps(
                    color: isSelected
                        ? (isDark
                              ? AppColors.primaryVolt
                              : AppColors.lightPrimary)
                        : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                  ).copyWith(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  ),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
