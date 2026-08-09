import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../utils/app_logger.dart';
import '../utils/backup_export_service.dart';
import 'sync_provider_interface.dart';

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final bool autoSyncEnabled;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.errorMessage,
    this.autoSyncEnabled = true,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool? autoSyncEnabled,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }
}

class SyncEngine {
  final AppDatabase db;
  final RemoteSyncProvider remoteProvider;
  static const String _keyLastSyncedAt = 'thews_last_synced_at';
  static const String _keyAutoSync = 'thews_auto_sync_enabled';

  SyncEngine({required this.db, required this.remoteProvider});

  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_keyLastSyncedAt);
    return iso != null ? DateTime.tryParse(iso) : null;
  }

  Future<bool> getAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSync) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, enabled);
  }

  Future<void> _saveLastSyncedAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSyncedAt, timestamp.toIso8601String());
  }

  /// Synchronizes local Drift SQLite data with the remote provider.
  Future<SyncState> performSync() async {
    AppLogger.sync('Starting cloud synchronization...');
    try {
      final isConnected = await remoteProvider.testConnection();
      if (!isConnected) {
        AppLogger.warning('Remote connection offline or unreachable');
        return const SyncState(
          status: SyncStatus.offline,
          errorMessage:
              'No active network connection or remote provider unreachable.',
        );
      }

      // Step 1: Export local payload
      final backupService = BackupExportService(db);
      final jsonBackupStr = await backupService.exportBackupJson();
      final Map<String, dynamic> backupMap = jsonDecode(jsonBackupStr);

      final localPayload = SyncPayload(
        timestamp: DateTime.now(),
        exercises:
            (backupMap['exercises'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        routines:
            (backupMap['routines'] as List?)
                ?.map((r) => Map<String, dynamic>.from(r as Map))
                .toList() ??
            [],
        workouts:
            (backupMap['workouts'] as List?)
                ?.map((w) => Map<String, dynamic>.from(w as Map))
                .toList() ??
            [],
      );

      // Step 2: Push local changes to remote
      final pushSuccess = await remoteProvider.pushLocalChanges(localPayload);
      if (!pushSuccess) {
        AppLogger.error('Failed to push records to remote cloud sync');
        return const SyncState(
          status: SyncStatus.error,
          errorMessage: 'Failed to push local records to remote cloud sync.',
        );
      }

      // Step 3: Fetch remote changes and reconcile
      final lastSyncedAt = await getLastSyncedAt();
      final remoteChanges = await remoteProvider.fetchRemoteChanges(
        lastSyncedAt,
      );

      if (remoteChanges.workouts.isNotEmpty) {
        final remoteBackupJson = jsonEncode({
          'workouts': remoteChanges.workouts,
        });
        await backupService.restoreBackupJson(remoteBackupJson);
        AppLogger.success('Reconciled remote records');
      }

      final now = DateTime.now();
      await _saveLastSyncedAt(now);
      AppLogger.success(
        'Cloud sync completed successfully at ${now.toIso8601String()}',
      );

      return SyncState(status: SyncStatus.success, lastSyncedAt: now);
    } catch (e, stack) {
      AppLogger.error('Sync failed with error: $e', error: e, stackTrace: stack);
      return SyncState(status: SyncStatus.error, errorMessage: e.toString());
    }
  }
}
