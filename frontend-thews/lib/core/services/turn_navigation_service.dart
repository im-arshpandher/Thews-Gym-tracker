import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/running/domain/gpx_course_navigator.dart';
import 'audio_coach_service.dart';

/// StateNotifier that manages active turn-by-turn course navigation.
class TurnNavigationNotifier extends StateNotifier<CourseNavigationState> {
  final AudioCoachService? audioCoach;

  TurnNavigationNotifier({this.audioCoach})
      : super(const CourseNavigationState());

  /// Starts navigation along a specified [course].
  void startCourse(CourseRoute course) {
    if (course.waypoints.isEmpty) return;

    final initialCues = course.turnCues.isNotEmpty
        ? course.turnCues
        : GpxCourseNavigator.generateTurnCues(course.waypoints, courseName: course.name);

    final updatedCourse = CourseRoute(
      id: course.id,
      name: course.name,
      description: course.description,
      waypoints: course.waypoints,
      turnCues: initialCues,
      totalDistanceMeters: course.totalDistanceMeters,
      elevationGainMeters: course.elevationGainMeters,
      isClosedLoop: course.isClosedLoop,
      source: course.source,
      createdAt: course.createdAt,
    );

    state = CourseNavigationState(
      activeCourse: updatedCourse,
      isNavigating: true,
      isVoiceMuted: false,
      currentCueIndex: 0,
      nextCue: initialCues.first,
      upcomingCueAfterNext: initialCues.length > 1 ? initialCues[1] : null,
      distanceToNextCueMeters: 0.0,
      remainingDistanceMeters: updatedCourse.totalDistanceMeters,
      courseProgressRatio: 0.0,
      isOffCourse: false,
      crossTrackDistanceMeters: 0.0,
      closestPointOnCourse: updatedCourse.waypoints.first,
      spokenCueAlertIds: const {},
      hasAnnouncedArrival: false,
    );

    // Initial voice greeting / start announcement
    if (initialCues.isNotEmpty && !state.isVoiceMuted) {
      _speakVoicePrompt(initialCues.first.instruction);
    }
  }

  /// Cancels and exits active turn-by-turn navigation.
  void stopCourse() {
    state = const CourseNavigationState();
  }

  /// Toggles mute state for audio turn prompts.
  void toggleVoiceMute() {
    state = state.copyWith(isVoiceMuted: !state.isVoiceMuted);
  }

  /// Updates navigation state upon incoming GPS position update from runner.
  void updateLocation(LatLng userLocation) {
    if (!state.isNavigating || state.activeCourse == null) return;

    final updatedState = GpxCourseNavigator.evaluateNavigationStep(
      currentState: state,
      userLocation: userLocation,
    );

    final alert = updatedState.pendingVoiceAlert;
    state = updatedState.copyWith(clearPendingVoiceAlert: true);

    if (alert != null && !state.isVoiceMuted) {
      _speakVoicePrompt(alert.textToSpeak);
    }
  }

  void _speakVoicePrompt(String text) {
    try {
      audioCoach?.speak(text);
    } catch (e) {
      debugPrint('TurnNavigation speak prompt notice: $e');
    }
  }
}

/// Provider for TurnNavigationNotifier.
final turnNavigationProvider =
    StateNotifierProvider<TurnNavigationNotifier, CourseNavigationState>((ref) {
  final audioCoach = ref.watch(audioCoachServiceProvider.notifier);
  return TurnNavigationNotifier(audioCoach: audioCoach);
});
