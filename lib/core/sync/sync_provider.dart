import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import 'mock_remote_sync_provider.dart';
import 'sync_engine.dart';
import 'sync_provider_interface.dart';

final remoteSyncProvider = Provider<RemoteSyncProvider>((ref) {
  return MockRemoteSyncProvider();
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final remote = ref.watch(remoteSyncProvider);
  return SyncEngine(db: db, remoteProvider: remote);
});

class SyncStateNotifier extends StateNotifier<SyncState> {
  final SyncEngine syncEngine;

  SyncStateNotifier(this.syncEngine) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    final lastSynced = await syncEngine.getLastSyncedAt();
    final autoSync = await syncEngine.getAutoSyncEnabled();
    state = state.copyWith(lastSyncedAt: lastSynced, autoSyncEnabled: autoSync);
  }

  Future<void> triggerSync() async {
    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);
    final newState = await syncEngine.performSync();
    state = newState.copyWith(autoSyncEnabled: state.autoSyncEnabled);
  }

  Future<void> setAutoSync(bool enabled) async {
    await syncEngine.setAutoSyncEnabled(enabled);
    state = state.copyWith(autoSyncEnabled: enabled);
  }
}

final syncStateNotifierProvider =
    StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
      final engine = ref.watch(syncEngineProvider);
      return SyncStateNotifier(engine);
    });
