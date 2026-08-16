import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/segment_storage_service.dart';
import 'live_segment_models.dart';

/// State of the Live Segment & Ghost Racer tracking engine.
class LiveSegmentEngineState {
  final LiveSegmentEffort? activeEffort;
  final RunSegment? selectedGhostSegment;
  final GhostRunnerTelemetry? ghostTelemetry;
  final List<RunSegment> availableSegments;
  final bool isTrackingSegment;

  const LiveSegmentEngineState({
    this.activeEffort,
    this.selectedGhostSegment,
    this.ghostTelemetry,
    this.availableSegments = const [],
    this.isTrackingSegment = false,
  });

  bool get hasActiveGhost =>
      selectedGhostSegment != null || activeEffort != null;

  LiveSegmentEngineState copyWith({
    LiveSegmentEffort? activeEffort,
    bool clearEffort = false,
    RunSegment? selectedGhostSegment,
    bool clearGhostSegment = false,
    GhostRunnerTelemetry? ghostTelemetry,
    bool clearGhostTelemetry = false,
    List<RunSegment>? availableSegments,
    bool? isTrackingSegment,
  }) {
    return LiveSegmentEngineState(
      activeEffort: clearEffort ? null : (activeEffort ?? this.activeEffort),
      selectedGhostSegment: clearGhostSegment
          ? null
          : (selectedGhostSegment ?? this.selectedGhostSegment),
      ghostTelemetry: clearGhostTelemetry
          ? null
          : (ghostTelemetry ?? this.ghostTelemetry),
      availableSegments: availableSegments ?? this.availableSegments,
      isTrackingSegment: isTrackingSegment ?? this.isTrackingSegment,
    );
  }
}

/// Real-time engine monitoring live GPS coordinates against route segments and Ghost Racers.
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

  /// Manually select a segment to race against as a Ghost Racer.
  void selectGhostSegment(RunSegment? segment) {
    if (segment == null) {
      clearGhostSegment();
      return;
    }
    final targetSecs = segment.bestTimeSeconds ??
        ((segment.distanceMeters / 1000.0) * 300.0).round();
    final startLatLng = segment.startPoint.toLatLng();

    state = state.copyWith(
      selectedGhostSegment: segment,
      ghostTelemetry: GhostRunnerTelemetry(
        segment: segment,
        ghostPosition: startLatLng,
        ghostDistanceMeters: 0.0,
        userDistanceMeters: 0.0,
        deltaDistanceMeters: 0.0,
        deltaTimeSeconds: 0.0,
        isRunnerAhead: true,
        ghostSpeedMps: segment.distanceMeters / targetSecs,
        ghostProgressFraction: 0.0,
        userProgressFraction: 0.0,
        ghostTargetSeconds: targetSecs,
        userElapsedSeconds: 0,
      ),
    );
  }

  /// Clears active Ghost selection.
  void clearGhostSegment() {
    _segmentStartTime = null;
    _accumulatedDistance = 0.0;
    _lastPosition = null;
    state = state.copyWith(
      clearGhostSegment: true,
      clearGhostTelemetry: true,
      clearEffort: true,
      isTrackingSegment: false,
    );
  }

  /// Evaluates current GPS location. Called on every GPS waypoint update.
  void onLocationUpdate({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    final currentPos = LatLng(latitude, longitude);
    const distanceCalculator = Distance();

    // 1. If actively tracking a segment effort
    if (state.isTrackingSegment && state.activeEffort != null) {
      final activeSeg = state.activeEffort!.segment;
      final startTime = _segmentStartTime ?? timestamp;
      final elapsedSecs =
          math.max(1, timestamp.difference(startTime).inSeconds);

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
      final userProgressFraction =
          (_accumulatedDistance / totalSegDist).clamp(0.0, 1.0);

      final totalTargetSeconds = activeSeg.bestTimeSeconds ??
          ((totalSegDist / 1000.0) * 300.0).round();

      final ghostSpeedMps = totalSegDist / totalTargetSeconds;
      final ghostDistance =
          (elapsedSecs * ghostSpeedMps).clamp(0.0, totalSegDist);
      final ghostProgressFraction = (ghostDistance / totalSegDist).clamp(0.0, 1.0);

      final ghostPos = _calculateInterpolatedPosition(
        activeSeg,
        ghostDistance,
        totalSegDist,
      );

      final deltaDistanceMeters = _accumulatedDistance - ghostDistance;
      final targetAtCurrentProgress =
          (totalTargetSeconds * userProgressFraction).round();
      final timeDelta = (elapsedSecs - targetAtCurrentProgress).toDouble();
      final isAhead = deltaDistanceMeters >= 0.0;

      // Check if reached finish line (within 30m of end point and >= 80% progress)
      final distToEnd = distanceCalculator.as(
        LengthUnit.Meter,
        currentPos,
        activeSeg.endPoint.toLatLng(),
      );

      final isCompleted = distToEnd <= 30.0 && userProgressFraction >= 0.80;
      final isNewPr = isCompleted &&
          (activeSeg.bestTimeSeconds == null ||
              elapsedSecs < activeSeg.bestTimeSeconds!);

      if (isCompleted) {
        _storageService.recordSegmentEffort(
          segmentId: activeSeg.id,
          durationSeconds: elapsedSecs,
        );
        refreshSegments();
      }

      final ghostTelem = GhostRunnerTelemetry(
        segment: activeSeg,
        ghostPosition: ghostPos,
        ghostDistanceMeters: ghostDistance,
        userDistanceMeters: _accumulatedDistance,
        deltaDistanceMeters: deltaDistanceMeters,
        deltaTimeSeconds: timeDelta,
        isRunnerAhead: isAhead,
        ghostSpeedMps: ghostSpeedMps,
        ghostProgressFraction: ghostProgressFraction,
        userProgressFraction: userProgressFraction,
        ghostTargetSeconds: totalTargetSeconds,
        userElapsedSeconds: elapsedSecs,
      );

      state = state.copyWith(
        activeEffort: LiveSegmentEffort(
          segment: activeSeg,
          elapsedSeconds: elapsedSecs,
          targetSeconds: totalTargetSeconds,
          distanceTraversedMeters: _accumulatedDistance,
          progressFraction: userProgressFraction,
          timeDeltaSeconds: timeDelta,
          isAhead: isAhead,
          isCompleted: isCompleted,
          isNewPr: isNewPr,
        ),
        ghostTelemetry: ghostTelem,
        isTrackingSegment: !isCompleted,
      );

      if (isCompleted) {
        _segmentStartTime = null;
        _accumulatedDistance = 0.0;
        _lastPosition = null;
      }
      return;
    }

    // 2. If a specific Ghost Segment was manually selected
    if (state.selectedGhostSegment != null) {
      final selectedSeg = state.selectedGhostSegment!;
      final distToStart = distanceCalculator.as(
        LengthUnit.Meter,
        currentPos,
        selectedSeg.startPoint.toLatLng(),
      );

      // Start line trigger radius: 35 meters
      if (distToStart <= 35.0) {
        _segmentStartTime = timestamp;
        _accumulatedDistance = 0.0;
        _lastPosition = currentPos;

        final targetSecs = selectedSeg.bestTimeSeconds ??
            ((selectedSeg.distanceMeters / 1000.0) * 300.0).round();

        state = state.copyWith(
          isTrackingSegment: true,
          activeEffort: LiveSegmentEffort(
            segment: selectedSeg,
            elapsedSeconds: 0,
            targetSeconds: targetSecs,
            distanceTraversedMeters: 0.0,
            progressFraction: 0.0,
            timeDeltaSeconds: 0.0,
            isAhead: true,
          ),
          ghostTelemetry: GhostRunnerTelemetry(
            segment: selectedSeg,
            ghostPosition: selectedSeg.startPoint.toLatLng(),
            ghostDistanceMeters: 0.0,
            userDistanceMeters: 0.0,
            deltaDistanceMeters: 0.0,
            deltaTimeSeconds: 0.0,
            isRunnerAhead: true,
            ghostSpeedMps: selectedSeg.distanceMeters / targetSecs,
            ghostProgressFraction: 0.0,
            userProgressFraction: 0.0,
            ghostTargetSeconds: targetSecs,
            userElapsedSeconds: 0,
          ),
        );
        return;
      }
    }

    // 3. Auto-detect start points of all available segments (25m trigger)
    for (final seg in state.availableSegments) {
      final distToStart = distanceCalculator.as(
        LengthUnit.Meter,
        currentPos,
        seg.startPoint.toLatLng(),
      );

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
          ghostTelemetry: GhostRunnerTelemetry(
            segment: seg,
            ghostPosition: seg.startPoint.toLatLng(),
            ghostDistanceMeters: 0.0,
            userDistanceMeters: 0.0,
            deltaDistanceMeters: 0.0,
            deltaTimeSeconds: 0.0,
            isRunnerAhead: true,
            ghostSpeedMps: seg.distanceMeters / targetSecs,
            ghostProgressFraction: 0.0,
            userProgressFraction: 0.0,
            ghostTargetSeconds: targetSecs,
            userElapsedSeconds: 0,
          ),
        );
        break;
      }
    }
  }

  /// Computes the exact interpolated coordinate along the segment's polyline at [targetDistance].
  LatLng _calculateInterpolatedPosition(
    RunSegment segment,
    double targetDistance,
    double totalDistance,
  ) {
    if (segment.polyline.isEmpty) return segment.startPoint.toLatLng();
    if (segment.polyline.length == 1 || targetDistance <= 0.0) {
      return segment.polyline.first.toLatLng();
    }
    if (targetDistance >= totalDistance) {
      return segment.polyline.last.toLatLng();
    }

    const distCalc = Distance();
    double currentAccum = 0.0;

    for (int i = 0; i < segment.polyline.length - 1; i++) {
      final p1 = segment.polyline[i].toLatLng();
      final p2 = segment.polyline[i + 1].toLatLng();
      final segLen = distCalc.as(LengthUnit.Meter, p1, p2);

      if (currentAccum + segLen >= targetDistance && segLen > 0) {
        final remaining = targetDistance - currentAccum;
        final frac = (remaining / segLen).clamp(0.0, 1.0);
        final lat = p1.latitude + frac * (p2.latitude - p1.latitude);
        final lng = p1.longitude + frac * (p2.longitude - p1.longitude);
        return LatLng(lat, lng);
      }
      currentAccum += segLen;
    }

    return segment.polyline.last.toLatLng();
  }

  /// Cancels or resets current segment tracking without removing ghost target.
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
