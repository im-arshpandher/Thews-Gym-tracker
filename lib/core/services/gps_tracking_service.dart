import 'dart:async';
import 'dart:math' as math;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../utils/gpx_parser.dart';

class RunSplit {
  final int splitIndex; // 1-based index (e.g. Km 1, Km 2)
  final double distanceMeters;
  final int durationSeconds;
  final double paceSecondsPerKm;

  const RunSplit({
    required this.splitIndex,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.paceSecondsPerKm,
  });

  String get formattedPace {
    if (paceSecondsPerKm <= 0 || paceSecondsPerKm.isInfinite) return '--:-- /km';
    final mins = (paceSecondsPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (paceSecondsPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs /km';
  }
}

class RunTrackingState {
  final bool isTracking;
  final bool isPaused;
  final String activityType; // 'run' | 'walk' | 'cycle'
  final int durationSeconds;
  final double distanceMeters;
  final double elevationGainMeters;
  final double currentPaceSecondsPerKm;
  final double avgPaceSecondsPerKm;
  final double currentSpeedKmH;
  final double headingDegrees;
  final List<GpxPoint> waypoints;
  final List<RunSplit> splits;
  final bool hasLocationPermission;
  final String? permissionStatusMessage;

  const RunTrackingState({
    this.isTracking = false,
    this.isPaused = false,
    this.activityType = 'run',
    this.durationSeconds = 0,
    this.distanceMeters = 0.0,
    this.elevationGainMeters = 0.0,
    this.currentPaceSecondsPerKm = 0.0,
    this.avgPaceSecondsPerKm = 0.0,
    this.currentSpeedKmH = 0.0,
    this.headingDegrees = 0.0,
    this.waypoints = const [],
    this.splits = const [],
    this.hasLocationPermission = false,
    this.permissionStatusMessage,
  });

  RunTrackingState copyWith({
    bool? isTracking,
    bool? isPaused,
    String? activityType,
    int? durationSeconds,
    double? distanceMeters,
    double? elevationGainMeters,
    double? currentPaceSecondsPerKm,
    double? avgPaceSecondsPerKm,
    double? currentSpeedKmH,
    double? headingDegrees,
    List<GpxPoint>? waypoints,
    List<RunSplit>? splits,
    bool? hasLocationPermission,
    String? permissionStatusMessage,
  }) {
    return RunTrackingState(
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      activityType: activityType ?? this.activityType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm ?? this.avgPaceSecondsPerKm,
      currentSpeedKmH: currentSpeedKmH ?? this.currentSpeedKmH,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      waypoints: waypoints ?? this.waypoints,
      splits: splits ?? this.splits,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      permissionStatusMessage:
          permissionStatusMessage ?? this.permissionStatusMessage,
    );
  }

  String get formattedDuration {
    final mins = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (durationSeconds % 60).toString().padLeft(2, '0');
    final hrs = durationSeconds ~/ 3600;
    if (hrs > 0) {
      final remMins = ((durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      return '$hrs:$remMins:$secs';
    }
    return '$mins:$secs';
  }

  String get formattedDistanceKm {
    return (distanceMeters / 1000.0).toStringAsFixed(2);
  }

  String get formattedAvgPace {
    if (avgPaceSecondsPerKm <= 0 || avgPaceSecondsPerKm.isInfinite) return '--:--';
    final mins = (avgPaceSecondsPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (avgPaceSecondsPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get formattedCurrentPace {
    if (currentPaceSecondsPerKm <= 0 || currentPaceSecondsPerKm.isInfinite) {
      return '--:--';
    }
    final mins = (currentPaceSecondsPerKm ~/ 60).toString().padLeft(2, '0');
    final secs = (currentPaceSecondsPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class RunTrackingNotifier extends StateNotifier<RunTrackingState> {
  final AppDatabase db;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  static const String _keyLastLat = 'last_known_gps_lat';
  static const String _keyLastLng = 'last_known_gps_lng';

  DateTime? _trackingStartTime;
  DateTime? _pauseStartTime;
  Duration _totalPausedDuration = Duration.zero;
  double _lastSplitDistance = 0.0;
  int _lastSplitDuration = 0;
  double _lastSensorMagnitude = 0.0;
  double _lastValidElevation = 0.0;

  RunTrackingNotifier(this.db) : super(const RunTrackingState()) {
    _initInitialLocation();
  }

  Future<void> _initInitialLocation() async {
    await _loadCachedLastLocation();
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final lastPoint = GpxPoint(
          latitude: lastPos.latitude,
          longitude: lastPos.longitude,
          elevation: lastPos.altitude,
          timestamp: lastPos.timestamp,
        );
        _saveCachedLastLocation(lastPos.latitude, lastPos.longitude);
        _lastValidElevation = lastPos.altitude;
        state = state.copyWith(waypoints: [lastPoint]);
      }
    } catch (_) {}
    await checkGpsStatusAndFetchLocation();
  }

  /// Load cached GPS coordinates from SharedPreferences
  Future<void> _loadCachedLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_keyLastLat);
      final lng = prefs.getDouble(_keyLastLng);
      if (lat != null && lng != null) {
        final cachedPoint = GpxPoint(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
        );
        if (state.waypoints.isEmpty) {
          state = state.copyWith(waypoints: [cachedPoint]);
        }
      }
    } catch (_) {}
  }

  /// Save last known real GPS coordinates to SharedPreferences
  Future<void> _saveCachedLastLocation(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLastLat, lat);
      await prefs.setDouble(_keyLastLng, lng);
    } catch (_) {}
  }

  /// Check phone location status and fetch initial location
  Future<void> checkGpsStatusAndFetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          hasLocationPermission: false,
          permissionStatusMessage: 'Location services (GPS) are turned off.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          hasLocationPermission: false,
          permissionStatusMessage: 'GPS permission needed for route tracking.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          hasLocationPermission: false,
          permissionStatusMessage:
              'GPS permission denied. Tap GRANT GPS for App Settings.',
        );
        return;
      }

      state = state.copyWith(
        hasLocationPermission: true,
        permissionStatusMessage: null,
      );

      await fetchCurrentLocation();
    } catch (_) {}
  }

  /// Request Phone GPS Permissions or open OS Settings
  Future<void> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        state = state.copyWith(
          hasLocationPermission: true,
          permissionStatusMessage: null,
        );
        await fetchCurrentLocation();
      }
    } on MissingPluginException {
      state = state.copyWith(
        permissionStatusMessage:
            'GPS plugin requires full app restart. Stop and run `flutter run`.',
      );
    } catch (e) {
      state = state.copyWith(
        permissionStatusMessage: 'Error requesting GPS: $e',
      );
    }
  }

  Future<void> fetchCurrentLocation() async {
    try {
      final currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      );

      final initialPoint = GpxPoint(
        latitude: currentPos.latitude,
        longitude: currentPos.longitude,
        elevation: currentPos.altitude,
        timestamp: currentPos.timestamp,
      );

      _saveCachedLastLocation(currentPos.latitude, currentPos.longitude);
      _lastValidElevation = currentPos.altitude;

      if (state.waypoints.isEmpty) {
        state = state.copyWith(
          waypoints: [initialPoint],
          headingDegrees: currentPos.heading >= 0
              ? currentPos.heading
              : state.headingDegrees,
        );
      }
    } catch (_) {}
  }

  void setActivityType(String activityType) {
    state = state.copyWith(activityType: activityType);
  }

  int _getActiveElapsedSeconds() {
    if (_trackingStartTime == null) return state.durationSeconds;
    var totalPaused = _totalPausedDuration;
    if (state.isPaused && _pauseStartTime != null) {
      totalPaused += DateTime.now().difference(_pauseStartTime!);
    }
    final rawSecs = DateTime.now().difference(_trackingStartTime!).inSeconds;
    final activeSecs = rawSecs - totalPaused.inSeconds;
    return math.max(0, activeSecs);
  }

  Future<void> startTracking({String? activityType}) async {
    final type = activityType ?? state.activityType;
    _stopAllTimersAndStreams();

    // Ensure GPS permissions are requested before tracking starts
    await requestLocationPermission();

    _trackingStartTime = DateTime.now();
    _pauseStartTime = null;
    _totalPausedDuration = Duration.zero;
    _lastSplitDistance = 0.0;
    _lastSplitDuration = 0;

    state = RunTrackingState(
      isTracking: true,
      isPaused: false,
      activityType: type,
      durationSeconds: 0,
      distanceMeters: 0.0,
      elevationGainMeters: 0.0,
      currentPaceSecondsPerKm: 0.0,
      avgPaceSecondsPerKm: 0.0,
      currentSpeedKmH: 0.0,
      headingDegrees: state.headingDegrees,
      waypoints: state.waypoints.isNotEmpty ? [state.waypoints.last] : [],
      splits: [],
      hasLocationPermission: state.hasLocationPermission,
    );

    // Wall-clock elapsed duration timer (accurately subtracts paused intervals)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isPaused && _trackingStartTime != null) {
        final elapsedSecs = _getActiveElapsedSeconds();
        final avgPace = state.distanceMeters > 5.0
            ? (elapsedSecs / (state.distanceMeters / 1000.0))
            : 0.0;
        state = state.copyWith(
          durationSeconds: elapsedSecs,
          avgPaceSecondsPerKm: avgPace,
        );
      }
    });

    // Start accelerometer & magnetometer sensor fusion stream
    _initSensorFusion();

    // Start real phone GPS position stream
    _startRealGpsStream();
  }

  void _startRealGpsStream() {
    try {
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: "Outdoor Activity Active",
            notificationText: "Tracking your workout telemetry & route in background",
            notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWakeLock: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        );
      }

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (position) {
          if (!state.isTracking || state.isPaused) return;

          // Strict indoor/weak signal accuracy filter (ignore GPS drift over 25 meters)
          if (position.accuracy > 25.0) return;

          // Sensor fusion check: filter GPS drift if phone is still
          if (_lastSensorMagnitude < 0.1 && position.speed < 0.3) {
            return;
          }

          _processNewPosition(
            position.latitude,
            position.longitude,
            position.altitude,
            position.speed,
            position.heading,
            position.timestamp,
          );
        },
        onError: (err) {
          state = state.copyWith(
            permissionStatusMessage: 'GPS stream error: $err',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        permissionStatusMessage: 'Could not access hardware GPS: $e',
      );
    }
  }

  void _initSensorFusion() {
    try {
      _sensorSubscription = userAccelerometerEventStream().listen((event) {
        // Calculate accelerometer magnitude: sqrt(x^2 + y^2 + z^2)
        _lastSensorMagnitude = math.sqrt(
          (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
        );
      }, onError: (_) {});

      _magnetometerSubscription = magnetometerEventStream().listen((event) {
        // Calculate heading in degrees from magnetometer: atan2(y, x)
        final headingRad = math.atan2(event.y, event.x);
        double headingDeg = headingRad * (180.0 / math.pi);
        if (headingDeg < 0) headingDeg += 360.0;

        // Smoothly update device facing heading
        if (!state.isTracking) {
          state = state.copyWith(headingDegrees: headingDeg);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _processNewPosition(
    double latitude,
    double longitude,
    double elevation,
    double speedMs,
    double heading,
    DateTime timestamp,
  ) {
    final newPoint = GpxPoint(
      latitude: latitude,
      longitude: longitude,
      elevation: math.max(0.0, elevation),
      timestamp: timestamp,
    );

    _saveCachedLastLocation(latitude, longitude);

    double addedDistance = 0.0;
    double addedElevationGain = 0.0;

    if (state.waypoints.isNotEmpty) {
      final lastPoint = state.waypoints.last;
      final distBetween = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        latitude,
        longitude,
      );

      // Filter out static GPS drift jitter (< 2.0m when speed is minimal)
      if (distBetween >= 2.0 && speedMs >= 0.3) {
        addedDistance = distBetween;

        final eleDiff = elevation - _lastValidElevation;
        // Ignore spurious altitude noise (< 1.5m)
        if (eleDiff >= 1.5) {
          addedElevationGain = eleDiff;
          _lastValidElevation = elevation;
        }
      }
    } else {
      _lastValidElevation = elevation;
    }

    final totalDist = state.distanceMeters + addedDistance;
    final eleGain = state.elevationGainMeters + addedElevationGain;
    final updatedWaypoints = addedDistance > 0 || state.waypoints.isEmpty
        ? [...state.waypoints, newPoint]
        : state.waypoints;

    // Accurate speed (km/h) & instant pace (sec/km)
    final speedKmH = speedMs >= 0.3 ? (speedMs * 3.6) : 0.0;
    final currentPace = speedMs >= 0.4
        ? (1000.0 / speedMs).clamp(120.0, 1800.0)
        : 0.0;

    final elapsedSecs = _getActiveElapsedSeconds();

    final updatedSplits = [...state.splits];
    if (totalDist - _lastSplitDistance >= 1000.0) {
      final splitIndex = updatedSplits.length + 1;
      final splitDist = totalDist - _lastSplitDistance;
      final splitDuration = elapsedSecs - _lastSplitDuration;
      final splitPace =
          splitDist > 0 ? (splitDuration / (splitDist / 1000.0)) : 0.0;

      updatedSplits.add(RunSplit(
        splitIndex: splitIndex,
        distanceMeters: splitDist,
        durationSeconds: splitDuration,
        paceSecondsPerKm: splitPace,
      ));

      _lastSplitDistance = totalDist;
      _lastSplitDuration = elapsedSecs;
    }

    final avgPace = totalDist > 5.0
        ? (elapsedSecs / (totalDist / 1000.0))
        : 0.0;

    final effectiveHeading = heading >= 0 ? heading : state.headingDegrees;

    state = state.copyWith(
      durationSeconds: elapsedSecs,
      distanceMeters: totalDist,
      elevationGainMeters: eleGain,
      currentPaceSecondsPerKm: currentPace,
      avgPaceSecondsPerKm: avgPace,
      currentSpeedKmH: speedKmH,
      headingDegrees: effectiveHeading,
      waypoints: updatedWaypoints,
      splits: updatedSplits,
    );
  }

  void pauseTracking() {
    if (!state.isPaused) {
      _pauseStartTime = DateTime.now();
      state = state.copyWith(isPaused: true);
    }
  }

  void resumeTracking() {
    if (state.isPaused) {
      if (_pauseStartTime != null) {
        _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }
      state = state.copyWith(isPaused: false);
    }
  }

  void stopTracking() {
    _stopAllTimersAndStreams();
    state = state.copyWith(isTracking: false, isPaused: false);
  }

  void _stopAllTimersAndStreams() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _sensorSubscription?.cancel();
    _magnetometerSubscription?.cancel();
  }

  Future<int?> finishAndSaveActivity() async {
    _stopAllTimersAndStreams();

    if (state.waypoints.isEmpty) {
      state = const RunTrackingState();
      return null;
    }

    final gpxXml = GpxParser.toGpxXml(
      state.waypoints,
      activityName: 'Outdoor ${state.activityType.toUpperCase()}',
    );

    final activityId = await db.insertRunActivity(
      RunActivitiesCompanion.insert(
        activityType: Value(state.activityType),
        startTime: Value(state.waypoints.first.timestamp),
        distanceMeters: Value(state.distanceMeters),
        durationSeconds: Value(state.durationSeconds),
        avgPaceSecondsPerKm: Value(state.avgPaceSecondsPerKm),
        elevationGainMeters: Value(state.elevationGainMeters),
        gpxData: Value(gpxXml),
      ),
    );

    state = const RunTrackingState();
    return activityId;
  }

  @override
  void dispose() {
    _stopAllTimersAndStreams();
    super.dispose();
  }
}

final runTrackingProvider =
    StateNotifierProvider<RunTrackingNotifier, RunTrackingState>((ref) {
  final db = ref.watch(databaseProvider);
  return RunTrackingNotifier(db);
});
