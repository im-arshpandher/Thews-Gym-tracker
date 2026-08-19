import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/running/domain/live_segment_models.dart';
import '../../features/settings/presentation/settings_provider.dart';

/// Service managing persistent local running & cycling segments.
class SegmentStorageService {
  static const String _storageKey = 'thews_saved_segments_v1';

  final SharedPreferences _prefs;

  SegmentStorageService(this._prefs);

  /// Loads all saved segments from local storage.
  List<RunSegment> loadSegments() {
    final rawJson = _prefs.getString(_storageKey);
    if (rawJson == null || rawJson.isEmpty) {
      return _getSeedSegments();
    }
    try {
      final List<dynamic> list = jsonDecode(rawJson);
      return list.map((item) => RunSegment.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return _getSeedSegments();
    }
  }

  /// Saves or updates a segment.
  Future<void> saveSegment(RunSegment segment) async {
    final current = loadSegments();
    final existingIndex = current.indexWhere((s) => s.id == segment.id);
    if (existingIndex >= 0) {
      current[existingIndex] = segment;
    } else {
      current.insert(0, segment);
    }
    await _saveAll(current);
  }

  /// Updates personal best time on a segment if a new PR was set.
  Future<RunSegment> recordSegmentEffort({
    required String segmentId,
    required int durationSeconds,
  }) async {
    final current = loadSegments();
    final index = current.indexWhere((s) => s.id == segmentId);
    if (index < 0) {
      throw Exception('Segment not found: $segmentId');
    }

    final seg = current[index];
    final bool isNewPr =
        seg.bestTimeSeconds == null || durationSeconds < seg.bestTimeSeconds!;

    final updated = seg.copyWith(
      bestTimeSeconds: isNewPr ? durationSeconds : seg.bestTimeSeconds,
      attemptCount: seg.attemptCount + 1,
    );

    current[index] = updated;
    await _saveAll(current);
    return updated;
  }

  /// Deletes a segment by ID.
  Future<void> deleteSegment(String segmentId) async {
    final current = loadSegments();
    current.removeWhere((s) => s.id == segmentId);
    await _saveAll(current);
  }

  Future<void> _saveAll(List<RunSegment> segments) async {
    final jsonStr = jsonEncode(segments.map((s) => s.toJson()).toList());
    await _prefs.setString(_storageKey, jsonStr);
  }

  static List<RunSegment> _getSeedSegments() {
    return <RunSegment>[];
  }
}

/// Provider for SegmentStorageService.
final segmentStorageServiceProvider = Provider<SegmentStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SegmentStorageService(prefs);
});

/// Notifier provider for all active segments.
class SegmentsNotifier extends StateNotifier<List<RunSegment>> {
  final SegmentStorageService _storage;

  SegmentsNotifier(this._storage) : super([]) {
    refresh();
  }

  void refresh() {
    state = _storage.loadSegments();
  }

  Future<void> addSegment(RunSegment segment) async {
    await _storage.saveSegment(segment);
    refresh();
  }

  Future<void> recordEffort(String segmentId, int durationSeconds) async {
    await _storage.recordSegmentEffort(
      segmentId: segmentId,
      durationSeconds: durationSeconds,
    );
    refresh();
  }

  Future<void> deleteSegment(String segmentId) async {
    await _storage.deleteSegment(segmentId);
    refresh();
  }
}

final segmentsProvider =
    StateNotifierProvider<SegmentsNotifier, List<RunSegment>>((ref) {
  final storage = ref.watch(segmentStorageServiceProvider);
  return SegmentsNotifier(storage);
});
