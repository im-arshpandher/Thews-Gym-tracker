import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/gpx_parser.dart';

/// Categorization of navigation turn cues.
enum TurnCueType {
  start,
  straight,
  slightRight,
  turnRight,
  sharpRight,
  uTurn,
  sharpLeft,
  turnLeft,
  slightLeft,
  roundabout,
  finish;

  IconData get icon {
    switch (this) {
      case TurnCueType.start:
        return Icons.play_circle_fill_rounded;
      case TurnCueType.straight:
        return Icons.straight_rounded;
      case TurnCueType.slightRight:
        return Icons.turn_slight_right_rounded;
      case TurnCueType.turnRight:
        return Icons.turn_right_rounded;
      case TurnCueType.sharpRight:
        return Icons.turn_sharp_right_rounded;
      case TurnCueType.uTurn:
        return Icons.u_turn_right_rounded;
      case TurnCueType.sharpLeft:
        return Icons.turn_sharp_left_rounded;
      case TurnCueType.turnLeft:
        return Icons.turn_left_rounded;
      case TurnCueType.slightLeft:
        return Icons.turn_slight_left_rounded;
      case TurnCueType.roundabout:
        return Icons.roundabout_right_rounded;
      case TurnCueType.finish:
        return Icons.flag_circle_rounded;
    }
  }

  String get shortName {
    switch (this) {
      case TurnCueType.start:
        return 'Start';
      case TurnCueType.straight:
        return 'Straight';
      case TurnCueType.slightRight:
        return 'Slight Right';
      case TurnCueType.turnRight:
        return 'Turn Right';
      case TurnCueType.sharpRight:
        return 'Sharp Right';
      case TurnCueType.uTurn:
        return 'U-Turn';
      case TurnCueType.sharpLeft:
        return 'Sharp Left';
      case TurnCueType.turnLeft:
        return 'Turn Left';
      case TurnCueType.slightLeft:
        return 'Slight Left';
      case TurnCueType.roundabout:
        return 'Roundabout';
      case TurnCueType.finish:
        return 'Destination';
    }
  }
}

/// A specific turn cue / navigation waypoint along a course.
class TurnCue {
  final String id;
  final TurnCueType type;
  final LatLng location;
  final String instruction;
  final String? streetName;
  final double cumulativeDistanceMeters;
  final int waypointIndex;

  const TurnCue({
    required this.id,
    required this.type,
    required this.location,
    required this.instruction,
    this.streetName,
    required this.cumulativeDistanceMeters,
    required this.waypointIndex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lat': location.latitude,
        'lng': location.longitude,
        'instruction': instruction,
        'streetName': streetName,
        'cumulativeDistanceMeters': cumulativeDistanceMeters,
        'waypointIndex': waypointIndex,
      };

  factory TurnCue.fromJson(Map<String, dynamic> json) {
    return TurnCue(
      id: json['id'] as String,
      type: TurnCueType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TurnCueType.straight,
      ),
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      instruction: json['instruction'] as String,
      streetName: json['streetName'] as String?,
      cumulativeDistanceMeters:
          (json['cumulativeDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      waypointIndex: (json['waypointIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Full planned athletic course with turn-by-turn navigation data.
class CourseRoute {
  final String id;
  final String name;
  final String description;
  final List<LatLng> waypoints;
  final List<TurnCue> turnCues;
  final double totalDistanceMeters;
  final double elevationGainMeters;
  final bool isClosedLoop;
  final String source; // 'gpx_import' | 'street_loop' | 'preset' | 'activity_record'
  final DateTime createdAt;

  const CourseRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.waypoints,
    required this.turnCues,
    required this.totalDistanceMeters,
    this.elevationGainMeters = 0.0,
    this.isClosedLoop = false,
    this.source = 'preset',
    required this.createdAt,
  });

  String get formattedDistance {
    if (totalDistanceMeters >= 1000) {
      final km = totalDistanceMeters / 1000.0;
      return '${km.toStringAsFixed(2)} km';
    }
    return '${totalDistanceMeters.toInt()} m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'waypoints': waypoints
            .map((w) => {'lat': w.latitude, 'lng': w.longitude})
            .toList(),
        'turnCues': turnCues.map((c) => c.toJson()).toList(),
        'totalDistanceMeters': totalDistanceMeters,
        'elevationGainMeters': elevationGainMeters,
        'isClosedLoop': isClosedLoop,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CourseRoute.fromJson(Map<String, dynamic> json) {
    final rawWaypoints = json['waypoints'] as List<dynamic>? ?? [];
    final waypoints = rawWaypoints.map((w) {
      final m = w as Map<String, dynamic>;
      return LatLng(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
      );
    }).toList();

    final rawCues = json['turnCues'] as List<dynamic>? ?? [];
    final cues = rawCues
        .map((c) => TurnCue.fromJson(c as Map<String, dynamic>))
        .toList();

    return CourseRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      waypoints: waypoints,
      turnCues: cues,
      totalDistanceMeters:
          (json['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      elevationGainMeters:
          (json['elevationGainMeters'] as num?)?.toDouble() ?? 0.0,
      isClosedLoop: json['isClosedLoop'] as bool? ?? false,
      source: json['source'] as String? ?? 'preset',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Voice and UI notification prompt produced by the navigation state machine.
class CourseVoiceAlert {
  final String cueId;
  final String textToSpeak;
  final bool isUrgent;

  const CourseVoiceAlert({
    required this.cueId,
    required this.textToSpeak,
    this.isUrgent = false,
  });
}

/// Live status of the runner along the active course.
class CourseNavigationState {
  final CourseRoute? activeCourse;
  final bool isNavigating;
  final bool isVoiceMuted;
  final int currentCueIndex;
  final TurnCue? nextCue;
  final TurnCue? upcomingCueAfterNext;
  final double distanceToNextCueMeters;
  final double remainingDistanceMeters;
  final double courseProgressRatio; // 0.0 to 1.0
  final bool isOffCourse;
  final double crossTrackDistanceMeters;
  final LatLng? closestPointOnCourse;
  final CourseVoiceAlert? pendingVoiceAlert;
  final Set<String> spokenCueAlertIds;
  final bool hasAnnouncedArrival;

  const CourseNavigationState({
    this.activeCourse,
    this.isNavigating = false,
    this.isVoiceMuted = false,
    this.currentCueIndex = 0,
    this.nextCue,
    this.upcomingCueAfterNext,
    this.distanceToNextCueMeters = 0.0,
    this.remainingDistanceMeters = 0.0,
    this.courseProgressRatio = 0.0,
    this.isOffCourse = false,
    this.crossTrackDistanceMeters = 0.0,
    this.closestPointOnCourse,
    this.pendingVoiceAlert,
    this.spokenCueAlertIds = const {},
    this.hasAnnouncedArrival = false,
  });

  CourseNavigationState copyWith({
    CourseRoute? activeCourse,
    bool clearActiveCourse = false,
    bool? isNavigating,
    bool? isVoiceMuted,
    int? currentCueIndex,
    TurnCue? nextCue,
    bool clearNextCue = false,
    TurnCue? upcomingCueAfterNext,
    bool clearUpcomingCueAfterNext = false,
    double? distanceToNextCueMeters,
    double? remainingDistanceMeters,
    double? courseProgressRatio,
    bool? isOffCourse,
    double? crossTrackDistanceMeters,
    LatLng? closestPointOnCourse,
    CourseVoiceAlert? pendingVoiceAlert,
    bool clearPendingVoiceAlert = false,
    Set<String>? spokenCueAlertIds,
    bool? hasAnnouncedArrival,
  }) {
    return CourseNavigationState(
      activeCourse: clearActiveCourse ? null : (activeCourse ?? this.activeCourse),
      isNavigating: isNavigating ?? this.isNavigating,
      isVoiceMuted: isVoiceMuted ?? this.isVoiceMuted,
      currentCueIndex: currentCueIndex ?? this.currentCueIndex,
      nextCue: clearNextCue ? null : (nextCue ?? this.nextCue),
      upcomingCueAfterNext: clearUpcomingCueAfterNext
          ? null
          : (upcomingCueAfterNext ?? this.upcomingCueAfterNext),
      distanceToNextCueMeters:
          distanceToNextCueMeters ?? this.distanceToNextCueMeters,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      courseProgressRatio: courseProgressRatio ?? this.courseProgressRatio,
      isOffCourse: isOffCourse ?? this.isOffCourse,
      crossTrackDistanceMeters:
          crossTrackDistanceMeters ?? this.crossTrackDistanceMeters,
      closestPointOnCourse:
          closestPointOnCourse ?? this.closestPointOnCourse,
      pendingVoiceAlert: clearPendingVoiceAlert
          ? null
          : (pendingVoiceAlert ?? this.pendingVoiceAlert),
      spokenCueAlertIds: spokenCueAlertIds ?? this.spokenCueAlertIds,
      hasAnnouncedArrival: hasAnnouncedArrival ?? this.hasAnnouncedArrival,
    );
  }
}

/// Offline Turn Cue Generator and Course Navigation Geometry Engine.
class GpxCourseNavigator {
  static const double _earthRadiusMeters = 6371000.0;
  static const double offCourseThresholdMeters = 25.0;
  static const double onCourseRecoveryThresholdMeters = 15.0;

  /// Generates human-friendly Turn Cues from a polyline of waypoints.
  static List<TurnCue> generateTurnCues(
    List<LatLng> points, {
    String? courseName,
    Map<int, String>? knownStreetNames,
  }) {
    if (points.isEmpty) return [];
    if (points.length < 2) {
      return [
        TurnCue(
          id: 'cue_0_start',
          type: TurnCueType.start,
          location: points.first,
          instruction: 'Start of course',
          cumulativeDistanceMeters: 0,
          waypointIndex: 0,
        ),
      ];
    }

    final cues = <TurnCue>[];
    final cumulativeDistances = _calculateCumulativeDistances(points);
    final totalDist = cumulativeDistances.last;

    // 1. Initial Start Cue
    cues.add(
      TurnCue(
        id: 'cue_0_start',
        type: TurnCueType.start,
        location: points.first,
        instruction: courseName != null
            ? 'Start course: $courseName. Follow route ahead'
            : 'Start course: Follow route ahead',
        streetName: knownStreetNames?[0],
        cumulativeDistanceMeters: 0,
        waypointIndex: 0,
      ),
    );

    // 2. Scan waypoints with windowed bearing delta analysis
    int lastCueIndex = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final prevIndex = math.max(0, i - 1);
      final nextIndex = math.min(points.length - 1, i + 1);

      // Distance from last turn cue to prevent flooding redundant turn cues within 20 meters
      final distFromLastCue = cumulativeDistances[i] - cumulativeDistances[lastCueIndex];
      if (distFromLastCue < 20.0 && i < points.length - 2) {
        continue;
      }

      final b1 = calculateBearing(points[prevIndex], points[i]);
      final b2 = calculateBearing(points[i], points[nextIndex]);
      final deltaDeg = _calculateAngularDeflection(b1, b2);

      final turnType = _classifyTurnType(deltaDeg);
      if (turnType != TurnCueType.straight) {
        final street = knownStreetNames?[i];
        final instruction = _buildTurnInstruction(turnType, street);

        cues.add(
          TurnCue(
            id: 'cue_${i}_${turnType.name}',
            type: turnType,
            location: points[i],
            instruction: instruction,
            streetName: street,
            cumulativeDistanceMeters: cumulativeDistances[i],
            waypointIndex: i,
          ),
        );
        lastCueIndex = i;
      }
    }

    // 3. Final Destination / Finish Cue
    cues.add(
      TurnCue(
        id: 'cue_${points.length - 1}_finish',
        type: TurnCueType.finish,
        location: points.last,
        instruction: 'Arriving at destination. Course complete',
        streetName: knownStreetNames?[points.length - 1],
        cumulativeDistanceMeters: totalDist,
        waypointIndex: points.length - 1,
      ),
    );

    return cues;
  }

  /// Evaluates athlete position along the course, detects proximity to turn cues,
  /// monitors cross-track deviation, and emits appropriate voice alerts.
  static CourseNavigationState evaluateNavigationStep({
    required CourseNavigationState currentState,
    required LatLng userLocation,
  }) {
    final course = currentState.activeCourse;
    if (course == null || course.waypoints.isEmpty) {
      return currentState;
    }

    final points = course.waypoints;
    final cues = course.turnCues;
    if (cues.isEmpty) return currentState;

    // 1. Calculate Cross-Track Distance to nearest polyline segment
    final crossTrackResult = calculateCrossTrackDistance(userLocation, points);
    final crossTrackDist = crossTrackResult.distanceMeters;
    final closestPt = crossTrackResult.closestPoint;
    final closestSegmentIdx = crossTrackResult.closestSegmentIndex;

    // Check off-course status
    bool isOffCourse = currentState.isOffCourse;
    if (!currentState.isOffCourse && crossTrackDist > offCourseThresholdMeters) {
      isOffCourse = true;
    } else if (currentState.isOffCourse &&
        crossTrackDist < onCourseRecoveryThresholdMeters) {
      isOffCourse = false;
    }

    // 2. Identify the active turn cue index based on closest segment index and user distance
    int activeCueIdx = currentState.currentCueIndex;
    while (activeCueIdx < cues.length - 1) {
      final cue = cues[activeCueIdx];
      final distToCue = distanceBetween(userLocation, cue.location);

      if (closestSegmentIdx >= cue.waypointIndex && distToCue < 25.0) {
        activeCueIdx++;
      } else if (closestSegmentIdx > cue.waypointIndex) {
        activeCueIdx++;
      } else {
        break;
      }
    }
    if (activeCueIdx >= cues.length) {
      activeCueIdx = cues.length - 1;
    }

    final nextCue = cues[activeCueIdx];
    final upcomingCue = activeCueIdx + 1 < cues.length ? cues[activeCueIdx + 1] : null;

    final distToNextCue = distanceBetween(userLocation, nextCue.location);

    // 3. Compute remaining distance to end of course
    final cumulativeDistances = _calculateCumulativeDistances(points);
    final totalCourseDist = course.totalDistanceMeters > 0
        ? course.totalDistanceMeters
        : cumulativeDistances.last;

    double remainingDist = 0.0;
    if (closestSegmentIdx < points.length - 1) {
      final distAlongRemaining = totalCourseDist - cumulativeDistances[closestSegmentIdx];
      remainingDist = math.max(0.0, distAlongRemaining);
    }

    final progressRatio = totalCourseDist > 0
        ? (1.0 - (remainingDist / totalCourseDist)).clamp(0.0, 1.0)
        : 0.0;

    // 4. Voice Alert Determination
    CourseVoiceAlert? pendingAlert;
    final updatedSpokenIds = Set<String>.from(currentState.spokenCueAlertIds);

    // A. Off-course alert trigger
    if (isOffCourse && !currentState.isOffCourse) {
      final offCourseKey = 'off_course_${DateTime.now().minute}';
      if (!updatedSpokenIds.contains(offCourseKey)) {
        updatedSpokenIds.add(offCourseKey);
        pendingAlert = CourseVoiceAlert(
          cueId: offCourseKey,
          textToSpeak:
              'Caution. You are ${crossTrackDist.toInt()} meters off course.',
          isUrgent: true,
        );
      }
    } else if (!isOffCourse && currentState.isOffCourse) {
      final backOnTrackKey = 'back_on_track_${DateTime.now().minute}';
      if (!updatedSpokenIds.contains(backOnTrackKey)) {
        updatedSpokenIds.add(backOnTrackKey);
        pendingAlert = CourseVoiceAlert(
          cueId: backOnTrackKey,
          textToSpeak: 'Back on course. Continue ahead.',
        );
      }
    }

    // B. Turn Cue Advance Warning (30m–60m before turn)
    if (pendingAlert == null && !isOffCourse) {
      if (nextCue.type == TurnCueType.finish) {
        if (distToNextCue <= 25.0 && !currentState.hasAnnouncedArrival) {
          final arrivalKey = 'cue_${nextCue.id}_arrival';
          if (!updatedSpokenIds.contains(arrivalKey)) {
            updatedSpokenIds.add(arrivalKey);
            pendingAlert = CourseVoiceAlert(
              cueId: arrivalKey,
              textToSpeak: nextCue.instruction,
            );
          }
        }
      } else {
        // Advance notice (~35 to 55 meters)
        final advanceKey = 'cue_${nextCue.id}_advance';
        if (distToNextCue <= 55.0 && distToNextCue >= 20.0 && !updatedSpokenIds.contains(advanceKey)) {
          updatedSpokenIds.add(advanceKey);
          final metersRounded = ((distToNextCue / 5).round() * 5).toInt();
          final spokenPrompt = _buildAdvanceVoicePrompt(nextCue, metersRounded);
          pendingAlert = CourseVoiceAlert(
            cueId: advanceKey,
            textToSpeak: spokenPrompt,
          );
        }

        // Immediate turn cue (~6 to 16 meters)
        final immediateKey = 'cue_${nextCue.id}_immediate';
        if (distToNextCue <= 16.0 && !updatedSpokenIds.contains(immediateKey)) {
          updatedSpokenIds.add(immediateKey);
          final immediatePrompt = _buildImmediateVoicePrompt(nextCue);
          pendingAlert = CourseVoiceAlert(
            cueId: immediateKey,
            textToSpeak: immediatePrompt,
          );
        }
      }
    }

    return currentState.copyWith(
      currentCueIndex: activeCueIdx,
      nextCue: nextCue,
      upcomingCueAfterNext: upcomingCue,
      distanceToNextCueMeters: distToNextCue,
      remainingDistanceMeters: remainingDist,
      courseProgressRatio: progressRatio,
      isOffCourse: isOffCourse,
      crossTrackDistanceMeters: crossTrackDist,
      closestPointOnCourse: closestPt,
      pendingVoiceAlert: pendingAlert,
      spokenCueAlertIds: updatedSpokenIds,
      hasAnnouncedArrival: currentState.hasAnnouncedArrival ||
          (nextCue.type == TurnCueType.finish && distToNextCue <= 20.0),
    );
  }

  /// Computes the minimum orthogonal or point distance from [point] to the nearest segment in [polyline].
  static CrossTrackResult calculateCrossTrackDistance(
    LatLng point,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) {
      return CrossTrackResult(distanceMeters: 0, closestPoint: point, closestSegmentIndex: 0);
    }
    if (polyline.length == 1) {
      final d = distanceBetween(point, polyline.first);
      return CrossTrackResult(distanceMeters: d, closestPoint: polyline.first, closestSegmentIndex: 0);
    }

    double minDistance = double.infinity;
    LatLng bestPoint = polyline.first;
    int bestSegmentIndex = 0;

    for (int i = 0; i < polyline.length - 1; i++) {
      final pA = polyline[i];
      final pB = polyline[i + 1];

      final proj = _projectPointOnSegment(point, pA, pB);
      final dist = distanceBetween(point, proj);

      if (dist < minDistance) {
        minDistance = dist;
        bestPoint = proj;
        bestSegmentIndex = i;
      }
    }

    return CrossTrackResult(
      distanceMeters: minDistance,
      closestPoint: bestPoint,
      closestSegmentIndex: bestSegmentIndex,
    );
  }

  /// Calculates geodesic distance between two points on Earth in meters (Haversine formula).
  static double distanceBetween(LatLng p1, LatLng p2) {
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
    final dLon = (p2.longitude - p1.longitude) * math.pi / 180.0;
    final lat1 = p1.latitude * math.pi / 180.0;
    final lat2 = p2.latitude * math.pi / 180.0;

    final a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2.0) * math.sin(dLon / 2.0);
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return _earthRadiusMeters * c;
  }

  /// Calculates initial compass bearing in degrees (0°..360°) from [from] to [to].
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final rad = math.atan2(y, x);
    final deg = (rad * 180.0 / math.pi + 360.0) % 360.0;
    return deg;
  }

  /// Converts a list of [GpxPoint] track points to a [CourseRoute].
  static CourseRoute fromGpxPoints({
    required String name,
    required List<GpxPoint> points,
    String description = '',
    String source = 'gpx_import',
  }) {
    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final totalDistance = GpxParser.calculateTotalDistanceMeters(points);
    final elevationGain = GpxParser.calculateElevationGainMeters(points);

    final isClosed = latLngs.length >= 4 &&
        distanceBetween(latLngs.first, latLngs.last) < 40.0;

    final turnCues = generateTurnCues(latLngs, courseName: name);

    return CourseRoute(
      id: 'course_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      waypoints: latLngs,
      turnCues: turnCues,
      totalDistanceMeters: totalDistance,
      elevationGainMeters: elevationGain,
      isClosedLoop: isClosed,
      source: source,
      createdAt: DateTime.now(),
    );
  }

  // --- Private Helpers ---

  static double _calculateAngularDeflection(double bearing1, double bearing2) {
    double diff = (bearing2 - bearing1 + 540.0) % 360.0 - 180.0;
    return diff;
  }

  static TurnCueType _classifyTurnType(double deflectionDeg) {
    if (deflectionDeg.abs() <= 20.0) {
      return TurnCueType.straight;
    } else if (deflectionDeg > 20.0 && deflectionDeg <= 55.0) {
      return TurnCueType.slightRight;
    } else if (deflectionDeg > 55.0 && deflectionDeg <= 125.0) {
      return TurnCueType.turnRight;
    } else if (deflectionDeg > 125.0 && deflectionDeg <= 160.0) {
      return TurnCueType.sharpRight;
    } else if (deflectionDeg.abs() > 160.0) {
      return TurnCueType.uTurn;
    } else if (deflectionDeg < -20.0 && deflectionDeg >= -55.0) {
      return TurnCueType.slightLeft;
    } else if (deflectionDeg < -55.0 && deflectionDeg >= -125.0) {
      return TurnCueType.turnLeft;
    } else if (deflectionDeg < -125.0 && deflectionDeg >= -160.0) {
      return TurnCueType.sharpLeft;
    }
    return TurnCueType.straight;
  }

  static String _buildTurnInstruction(TurnCueType type, String? streetName) {
    final target = streetName != null ? ' onto $streetName' : '';
    switch (type) {
      case TurnCueType.slightRight:
        return 'Slight right$target';
      case TurnCueType.turnRight:
        return 'Turn right$target';
      case TurnCueType.sharpRight:
        return 'Sharp right$target';
      case TurnCueType.uTurn:
        return 'Make a U-turn';
      case TurnCueType.slightLeft:
        return 'Slight left$target';
      case TurnCueType.turnLeft:
        return 'Turn left$target';
      case TurnCueType.sharpLeft:
        return 'Sharp left$target';
      case TurnCueType.roundabout:
        return 'Enter roundabout';
      case TurnCueType.start:
        return 'Start of course';
      case TurnCueType.finish:
        return 'Arriving at destination';
      case TurnCueType.straight:
        return 'Continue straight';
    }
  }

  static String _buildAdvanceVoicePrompt(TurnCue cue, int metersAhead) {
    final street = cue.streetName != null ? ' onto ${cue.streetName}' : '';
    switch (cue.type) {
      case TurnCueType.slightRight:
        return 'In $metersAhead meters, slight right$street';
      case TurnCueType.turnRight:
        return 'In $metersAhead meters, turn right$street';
      case TurnCueType.sharpRight:
        return 'In $metersAhead meters, sharp right$street';
      case TurnCueType.uTurn:
        return 'In $metersAhead meters, make a U-turn';
      case TurnCueType.slightLeft:
        return 'In $metersAhead meters, slight left$street';
      case TurnCueType.turnLeft:
        return 'In $metersAhead meters, turn left$street';
      case TurnCueType.sharpLeft:
        return 'In $metersAhead meters, sharp left$street';
      case TurnCueType.roundabout:
        return 'In $metersAhead meters, enter roundabout';
      case TurnCueType.finish:
        return 'Destination in $metersAhead meters';
      default:
        return 'In $metersAhead meters, ${cue.instruction.toLowerCase()}';
    }
  }

  static String _buildImmediateVoicePrompt(TurnCue cue) {
    final street = cue.streetName != null ? ' onto ${cue.streetName}' : '';
    switch (cue.type) {
      case TurnCueType.slightRight:
        return 'Slight right$street';
      case TurnCueType.turnRight:
        return 'Turn right now$street';
      case TurnCueType.sharpRight:
        return 'Sharp right now$street';
      case TurnCueType.uTurn:
        return 'Make a U-turn now';
      case TurnCueType.slightLeft:
        return 'Slight left$street';
      case TurnCueType.turnLeft:
        return 'Turn left now$street';
      case TurnCueType.sharpLeft:
        return 'Sharp left now$street';
      case TurnCueType.roundabout:
        return 'Enter roundabout';
      case TurnCueType.finish:
        return 'You have reached your destination';
      default:
        return cue.instruction;
    }
  }

  static List<double> _calculateCumulativeDistances(List<LatLng> points) {
    if (points.isEmpty) return [0.0];
    final list = <double>[0.0];
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distanceBetween(points[i], points[i + 1]);
      list.add(total);
    }
    return list;
  }

  static LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final latMean = (a.latitude + b.latitude) / 2.0 * math.pi / 180.0;
    final cosLat = math.cos(latMean);

    final xA = a.longitude * cosLat;
    final yA = a.latitude;
    final xB = b.longitude * cosLat;
    final yB = b.latitude;
    final xP = p.longitude * cosLat;
    final yP = p.latitude;

    final dx = xB - xA;
    final dy = yB - yA;
    final lenSq = dx * dx + dy * dy;

    if (lenSq < 1e-12) {
      return a;
    }

    final t = ((xP - xA) * dx + (yP - yA) * dy) / lenSq;
    final clampedT = t.clamp(0.0, 1.0);

    final projX = xA + clampedT * dx;
    final projY = yA + clampedT * dy;

    return LatLng(projY, projX / cosLat);
  }
}

/// Helper container holding cross-track orthogonal distance and closest point.
class CrossTrackResult {
  final double distanceMeters;
  final LatLng closestPoint;
  final int closestSegmentIndex;

  const CrossTrackResult({
    required this.distanceMeters,
    required this.closestPoint,
    required this.closestSegmentIndex,
  });
}
