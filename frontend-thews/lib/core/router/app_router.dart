import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/challenges/domain/challenge_models.dart';
import '../../features/challenges/presentation/challenge_detail_screen.dart';
import '../../features/challenges/presentation/challenges_screen.dart';
import '../../features/challenges/presentation/create_custom_challenge_screen.dart';
import '../../features/exercises/presentation/exercise_list_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/workout_session_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/running/presentation/animated_route_flyover_screen.dart';
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

CustomTransitionPage<T> _buildFadeSlideTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
      final slide = Tween<Offset>(
        begin: const Offset(0.0, 0.05),
        end: Offset.zero,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

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
                  pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
                    context: context,
                    state: state,
                    child: const RunHeatmapScreen(),
                  ),
                ),
                GoRoute(
                  path: 'history',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
                    context: context,
                    state: state,
                    child: const RunHistoryScreen(),
                  ),
                ),
                GoRoute(
                  path: 'summary/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final activityId = int.tryParse(idStr) ?? 0;
                    return _buildFadeSlideTransitionPage(
                      context: context,
                      state: state,
                      child: RunSummaryScreen(activityId: activityId),
                    );
                  },
                ),
                GoRoute(
                  path: 'segment-builder/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final activityId = int.tryParse(idStr) ?? 0;
                    return _buildFadeSlideTransitionPage(
                      context: context,
                      state: state,
                      child: SegmentBuilderScreen(activityId: activityId),
                    );
                  },
                ),
                GoRoute(
                  path: 'flyover/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final activityId = int.tryParse(idStr) ?? 0;
                    return _buildFadeSlideTransitionPage(
                      context: context,
                      state: state,
                      child: AnimatedRouteFlyoverScreen(activityId: activityId),
                    );
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
                  pageBuilder: (context, state) {
                    final idStr = state.pathParameters['id'] ?? '0';
                    final workoutId = int.tryParse(idStr) ?? 0;
                    return _buildFadeSlideTransitionPage(
                      context: context,
                      state: state,
                      child: WorkoutSessionDetailScreen(workoutId: workoutId),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // Branch 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
        context: context,
        state: state,
        child: const SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/routines',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
        context: context,
        state: state,
        child: const RoutinesScreen(),
      ),
    ),
    GoRoute(
      path: '/visualizer',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
        context: context,
        state: state,
        child: const MuscleVisualizationScreen(),
      ),
    ),
    GoRoute(
      path: '/exercises',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
        context: context,
        state: state,
        child: const ExerciseListScreen(),
      ),
    ),
    GoRoute(
      path: '/challenges',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
        context: context,
        state: state,
        child: const ChallengesScreen(),
      ),
      routes: [
        GoRoute(
          path: 'create',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _buildFadeSlideTransitionPage(
            context: context,
            state: state,
            child: const CreateCustomChallengeScreen(),
          ),
        ),
        GoRoute(
          path: 'detail/:id',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final extraChallenge = state.extra is LocalChallenge
                ? state.extra as LocalChallenge
                : null;
            return _buildFadeSlideTransitionPage(
              context: context,
              state: state,
              child: ChallengeDetailScreen(
                challengeId: id,
                initialChallenge: extraChallenge,
              ),
            );
          },
        ),
      ],
    ),
  ],
);
