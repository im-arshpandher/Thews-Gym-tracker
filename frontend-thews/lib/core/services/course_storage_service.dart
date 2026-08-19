import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/running/domain/gpx_course_navigator.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../database/app_database.dart';
import '../utils/gpx_parser.dart';

/// Storage & catalog manager for athletic GPX courses and preset loops.
class CourseStorageService {
  static const String _storageKey = 'thews_saved_courses_v1';
  final SharedPreferences _prefs;

  CourseStorageService(this._prefs);

  /// Loads all saved courses, seeding with default curated courses if empty.
  List<CourseRoute> loadCourses() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      final seeds = getCuratedSeedCourses();
      _saveAll(seeds);
      return seeds;
    }
    try {
      final List<dynamic> list = jsonDecode(raw);
      final courses = list
          .map((item) => CourseRoute.fromJson(item as Map<String, dynamic>))
          .toList();
      return courses.isNotEmpty ? courses : getCuratedSeedCourses();
    } catch (_) {
      return getCuratedSeedCourses();
    }
  }

  /// Saves or updates a course in storage.
  Future<void> saveCourse(CourseRoute course) async {
    final current = loadCourses();
    final idx = current.indexWhere((c) => c.id == course.id);
    if (idx >= 0) {
      current[idx] = course;
    } else {
      current.insert(0, course);
    }
    await _saveAll(current);
  }

  /// Deletes a course from storage.
  Future<void> deleteCourse(String courseId) async {
    final current = loadCourses();
    current.removeWhere((c) => c.id == courseId);
    await _saveAll(current);
  }

  /// Imports a GPX route from device file storage via FilePicker.
  Future<CourseRoute?> importCourseFromGpxFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'xml'],
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      String? xmlString;

      if (file.bytes != null) {
        xmlString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          xmlString = await f.readAsString();
        }
      }

      if (xmlString == null || xmlString.trim().isEmpty) return null;

      final points = GpxParser.parseGpxXml(xmlString);
      if (points.length < 2) return null;

      final fileName = file.name.replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '');
      final course = GpxCourseNavigator.fromGpxPoints(
        name: fileName.isNotEmpty ? fileName : 'Imported GPX Course',
        points: points,
        description: 'Imported from ${file.name}',
        source: 'gpx_import',
      );

      await saveCourse(course);
      return course;
    } catch (e) {
      debugPrint('Error importing GPX course: $e');
      return null;
    }
  }

  /// Converts a completed [RunActivityData] into a reusable [CourseRoute].
  Future<CourseRoute?> createCourseFromRunActivity(RunActivityData activity) async {
    if (activity.gpxData == null || activity.gpxData!.isEmpty) {
      return null;
    }

    try {
      final points = GpxParser.parseGpxXml(activity.gpxData!);
      if (points.length < 2) return null;

      final distKm = (activity.distanceMeters / 1000.0).toStringAsFixed(1);
      final course = GpxCourseNavigator.fromGpxPoints(
        name: 'Activity #${activity.id} ($distKm km)',
        points: points,
        description: 'Converted from workout session on ${activity.startTime.toLocal().toString().split('.').first}',
        source: 'activity_record',
      );

      await saveCourse(course);
      return course;
    } catch (e) {
      debugPrint('Error creating course from activity: $e');
      return null;
    }
  }

  /// Exports a [CourseRoute] to a standard GPX 1.1 XML string and opens system share dialog.
  Future<void> exportCourseGpx(CourseRoute course) async {
    final gpxPoints = course.waypoints.map((w) {
      return GpxPoint(
        latitude: w.latitude,
        longitude: w.longitude,
        elevation: 0.0,
        timestamp: DateTime.now(),
      );
    }).toList();

    final xml = GpxParser.toGpxXml(gpxPoints, activityName: course.name);
    await SharePlus.instance.share(
      ShareParams(
        text: xml,
        subject: '${course.name}.gpx',
      ),
    );
  }

  Future<void> _saveAll(List<CourseRoute> courses) async {
    final jsonStr = jsonEncode(courses.map((c) => c.toJson()).toList());
    await _prefs.setString(_storageKey, jsonStr);
  }

  /// Curated initial preset courses.
  static List<CourseRoute> getCuratedSeedCourses() {
    // 1. 5K Waterfront Circuit
    final circuit5kPoints = [
      const LatLng(37.7749, -122.4194),
      const LatLng(37.7760, -122.4150),
      const LatLng(37.7785, -122.4110),
      const LatLng(37.7820, -122.4120),
      const LatLng(37.7845, -122.4170),
      const LatLng(37.7815, -122.4220),
      const LatLng(37.7770, -122.4210),
      const LatLng(37.7749, -122.4194),
    ];

    // 2. 10K City Perimeter Loop
    final circuit10kPoints = [
      const LatLng(40.7128, -74.0060),
      const LatLng(40.7150, -73.9980),
      const LatLng(40.7220, -73.9900),
      const LatLng(40.7300, -73.9850),
      const LatLng(40.7380, -73.9920),
      const LatLng(40.7420, -74.0010),
      const LatLng(40.7350, -74.0100),
      const LatLng(40.7250, -74.0150),
      const LatLng(40.7180, -74.0120),
      const LatLng(40.7128, -74.0060),
    ];

    // 3. 1.6K Mile Tempo Sprint
    final mileTempoPoints = [
      const LatLng(34.0522, -118.2437),
      const LatLng(34.0550, -118.2400),
      const LatLng(34.0590, -118.2420),
      const LatLng(34.0620, -118.2460),
    ];

    return [
      CourseRoute(
        id: 'seed_5k_waterfront',
        name: '5K Waterfront Circuit',
        description: 'Fast, flat closed-loop circuit with sweeping river turns and clear mile checkpoints.',
        waypoints: circuit5kPoints,
        turnCues: GpxCourseNavigator.generateTurnCues(circuit5kPoints, courseName: '5K Waterfront Circuit'),
        totalDistanceMeters: 5020.0,
        elevationGainMeters: 18.0,
        isClosedLoop: true,
        source: 'preset',
        createdAt: DateTime(2026, 1, 1),
      ),
      CourseRoute(
        id: 'seed_10k_city_perimeter',
        name: '10K City Perimeter Loop',
        description: 'Endurance loop following wide avenues and landmark city corners with optimal road camber.',
        waypoints: circuit10kPoints,
        turnCues: GpxCourseNavigator.generateTurnCues(circuit10kPoints, courseName: '10K City Perimeter Loop'),
        totalDistanceMeters: 10050.0,
        elevationGainMeters: 45.0,
        isClosedLoop: true,
        source: 'preset',
        createdAt: DateTime(2026, 1, 1),
      ),
      CourseRoute(
        id: 'seed_mile_tempo',
        name: '1.6K Mile Tempo Sprint',
        description: 'Straight-line asphalt segment engineered for maximum aerobic threshold and pace testing.',
        waypoints: mileTempoPoints,
        turnCues: GpxCourseNavigator.generateTurnCues(mileTempoPoints, courseName: '1.6K Mile Tempo Sprint'),
        totalDistanceMeters: 1609.34,
        elevationGainMeters: 8.0,
        isClosedLoop: false,
        source: 'preset',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

/// Provider for CourseStorageService.
final courseStorageServiceProvider = Provider<CourseStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CourseStorageService(prefs);
});

/// Notifier providing list of available courses and course director operations.
class CourseDirectorNotifier extends StateNotifier<List<CourseRoute>> {
  final CourseStorageService _storage;

  CourseDirectorNotifier(this._storage) : super([]) {
    refresh();
  }

  void refresh() {
    state = _storage.loadCourses();
  }

  Future<CourseRoute?> importGpxFile() async {
    final imported = await _storage.importCourseFromGpxFile();
    if (imported != null) {
      refresh();
    }
    return imported;
  }

  Future<CourseRoute?> saveActivityAsCourse(RunActivityData activity) async {
    final created = await _storage.createCourseFromRunActivity(activity);
    if (created != null) {
      refresh();
    }
    return created;
  }

  Future<void> addCourse(CourseRoute course) async {
    await _storage.saveCourse(course);
    refresh();
  }

  Future<void> deleteCourse(String courseId) async {
    await _storage.deleteCourse(courseId);
    refresh();
  }

  Future<void> exportGpx(CourseRoute course) async {
    await _storage.exportCourseGpx(course);
  }
}

final courseDirectorProvider =
    StateNotifierProvider<CourseDirectorNotifier, List<CourseRoute>>((ref) {
  final storage = ref.watch(courseStorageServiceProvider);
  return CourseDirectorNotifier(storage);
});
