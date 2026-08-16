enum SyncStatus { idle, syncing, success, error, offline }

class SyncPayload {
  final DateTime timestamp;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> routines;
  final List<Map<String, dynamic>> workouts;

  SyncPayload({
    required this.timestamp,
    this.exercises = const [],
    this.routines = const [],
    this.workouts = const [],
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'exercises': exercises,
    'routines': routines,
    'workouts': workouts,
  };

  factory SyncPayload.fromJson(Map<String, dynamic> json) => SyncPayload(
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    exercises:
        (json['exercises'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    routines:
        (json['routines'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    workouts:
        (json['workouts'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
  );
}

abstract class RemoteSyncProvider {
  String get providerName;
  bool get isAuthenticated;

  Future<bool> testConnection();
  Future<SyncPayload> fetchRemoteChanges(DateTime? lastSyncedAt);
  Future<bool> pushLocalChanges(SyncPayload payload);
  Future<bool> authenticate(String apiKeyOrToken);
  Future<void> signOut();
}
