import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/segment_storage_service.dart';
import 'live_segment_models.dart';

/// State of the Live Segment tracking engine.
class LiveSegmentEngineState {
  final LiveSegmentEffort? activeEffort;
  final List<RunSegment> availableSegments;
  final bool isTrackingSegment;

  const LiveSegmentEngineState({
    this.activeEffort,
    this.availableSegments = const [],
    this.isTrackingSegment = false,
  });

  LiveSegmentEngineState copyWith({
    LiveSegmentEffort? activeEffort,
    bool clearEffort = false,
    List<RunSegment>? availableSegments,
    bool? isTrackingSegment,
  }) {
    return LiveSegmentEngineState(
      activeEffort: clearEffort ? null : (activeEffort ?? this.activeEffort),
      availableSegments: availableSegments ?? this.availableSegments,
      isTrackingSegment: isTrackingSegment ?? this.isTrackingSegment,
    );
  }
}

/// Real-time engine monitoring live GPS coordinates against route segments.
class LiveSegmentEngine extends StateNotifier<LiveSegmentEngineState> {
  final SegmentStorageService _storageService;

  DateTime? _segmentStartTime;
  double _accumulatedDistance = 0.0;
  LatLng? _lastPosition;

  LiveSegmentEngine(this._storageService) : super(const LiveSegmentEngineState()) {
    refreshSegments();
  }

  void refreshSegments() {
    final segments = _storageService.loadSegments();
    state = state.copyWith(availableSegments: segments);
  }

  /// Evaluates current GPS location. Called on every GPS waypoint update.
  void onLocationUpdate({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    final currentPos = LatLng(latitude, longitude);
    const distanceCalculator = Distance();

    // 1. If already tracking an active segment
    if (state.isTrackingSegment && state.activeEffort != null) {
      final activeSeg = state.activeEffort!.segment;
      final startTime = _segmentStartTime ?? timestamp;
      final elapsedSecs = math.max(1, timestamp.difference(startTime).inSeconds);

      if (_lastPosition != null) {
        final stepDist = distanceCalculator.as(
          LengthUnit.Meter,
          _lastPosition!,
          currentPos,
        );
        _accumulatedDistance += stepDist;
      }
      _lastPosition = currentPos;

      final totalSegDist = math.max(1.0, activeSeg.distanceMeters);
      final progressFraction = (_accumulatedDistance / totalSegDist).clamp(0.0, 1.0);

      // Baseline target: either bestTimeSeconds or default 5:00/km (300s/km)
      final totalTargetSeconds = activeSeg.bestTimeSeconds ??
          ((totalSegDist / 1000.0) * 300.0).round();

      final targetAtCurrentProgress = (totalTargetSeconds * progressFraction).round();
      final timeDelta = (elapsedSecs - targetAtCurrentProgress).toDouble();
      final isAhead = timeDelta <= 0.0;

      // Check if reached finish line (within 25m of end point and >= 80% progress)
      final distToEnd = distanceCalculator.as(
        LengthUnit.Meter,
        currentPos,
        activeSeg.endPoint.toLatLng(),
      );

      final isCompleted = distToEnd <= 30.0 && progressFraction >= 0.80;
      final isNewPr = isCompleted &&
          (activeSeg.bestTimeSeconds == null || elapsedSecs < activeSeg.bestTimeSeconds!);

      if (isCompleted) {
        _storageService.recordSegmentEffort(
          segmentId: activeSeg.id,
          durationSeconds: elapsedSecs,
        );
        refreshSegments();
      }

      state = state.copyWith(
        activeEffort: LiveSegmentEffort(
          segment: activeSeg,
          elapsedSeconds: elapsedSecs,
          targetSeconds: totalTargetSeconds,
          distanceTraversedMeters: _accumulatedDistance,
          progressFraction: progressFraction,
          timeDeltaSeconds: timeDelta,
          isAhead: isAhead,
          isCompleted: isCompleted,
          isNewPr: isNewPr,
        ),
        isTrackingSegment: !isCompleted,
      );

      if (isCompleted) {
        _segmentStartTime = null;
        _accumulatedDistance = 0.0;
        _lastPosition = null;
      }
      return;
    }

    // 2. Not currently tracking a segment -> Check if entering any segment start point
    for (final seg in state.availableSegments) {
      final distToStart = distanceCalculator.as(
        LengthUnit.Meter,
        currentPos,
        seg.startPoint.toLatLng(),
      );

      // Start line trigger radius: 25 meters
      if (distToStart <= 25.0) {
        _segmentStartTime = timestamp;
        _accumulatedDistance = 0.0;
        _lastPosition = currentPos;

        final targetSecs = seg.bestTimeSeconds ??
            ((seg.distanceMeters / 1000.0) * 300.0).round();

        state = state.copyWith(
          isTrackingSegment: true,
          activeEffort: LiveSegmentEffort(
            segment: seg,
            elapsedSeconds: 0,
            targetSeconds: targetSecs,
            distanceTraversedMeters: 0.0,
            progressFraction: 0.0,
            timeDeltaSeconds: 0.0,
            isAhead: true,
          ),
        );
        break;
      }
    }
  }

  /// Cancels or resets the current segment tracking.
  void resetSegmentTracking() {
    _segmentStartTime = null;
    _accumulatedDistance = 0.0;
    _lastPosition = null;
    state = state.copyWith(
      clearEffort: true,
      isTrackingSegment: false,
    );
  }
}

/// Provider for LiveSegmentEngine.
final liveSegmentEngineProvider =
    StateNotifierProvider<LiveSegmentEngine, LiveSegmentEngineState>((ref) {
  final storage = ref.watch(segmentStorageServiceProvider);
  return LiveSegmentEngine(storage);
});
