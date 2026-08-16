import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/challenges/presentation/challenges_screen.dart';
import '../../features/exercises/presentation/exercise_list_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/workout_session_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/running/presentation/run_heatmap_screen.dart';
import '../../features/running/presentation/run_history_screen.dart';
import '../../features/running/presentation/run_summary_screen.dart';
import '../../features/running/presentation/run_tracker_screen.dart';
import '../../features/running/presentation/segment_builder_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/workouts/presentation/active_session_screen.dart';
import '../../features/workouts/presentation/dashboard_screen.dart';
import '../../features/workouts/presentation/muscle_visualization_screen.dart';
import '../../features/workouts/presentation/routines_screen.dart';
import '../presentation/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Dashboard / Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        // Branch 1: Outdoor Run Tracker
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/running',
              builder: (context, state) => const RunTrackerScreen(),
              routes: [
                GoRoute(
                  path: 'heatmap',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const RunHeatmapScreen(),
                ),
                GoRoute(
                  path: 'history',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const RunHistoryScreen(),
                ),
                GoRoute(
                  path: 'summary/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final activityId = int.tryParse(idStr) ?? 0;
                    return RunSummaryScreen(activityId: activityId);
                  },
                ),
                GoRoute(
                  path: 'segment-builder/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final activityId = int.tryParse(idStr) ?? 0;
                    return SegmentBuilderScreen(activityId: activityId);
                  },
                ),
              ],
            ),
          ],
        ),
        // Branch 2: Log Workout / Active Session
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/log',
              builder: (context, state) => const ActiveSessionScreen(),
            ),
          ],
        ),
        // Branch 3: History
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
              routes: [
                GoRoute(
                  path: 'workout/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final workoutId = int.tryParse(idStr) ?? 0;
                    return WorkoutSessionDetailScreen(workoutId: workoutId);
                  },
                ),
              ],
            ),
          ],
        ),
        // Branch 4: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/routines',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RoutinesScreen(),
    ),
    GoRoute(
      path: '/visualizer',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MuscleVisualizationScreen(),
    ),
    GoRoute(
      path: '/exercises',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExerciseListScreen(),
    ),
    GoRoute(
      path: '/challenges',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ChallengesScreen(),
    ),
    GoRoute(
      path: '/profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
