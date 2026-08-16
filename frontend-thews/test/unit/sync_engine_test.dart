import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/sync/mock_remote_sync_provider.dart';
import 'package:thews/core/sync/sync_engine.dart';
import 'package:thews/core/sync/sync_provider_interface.dart';

class FailingRemoteSyncProvider extends MockRemoteSyncProvider {
  @override
  Future<bool> testConnection() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MockRemoteSyncProvider mockRemote;
  late SyncEngine syncEngine;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockRemote = MockRemoteSyncProvider();
    syncEngine = SyncEngine(db: db, remoteProvider: mockRemote);
  });

  tearDown(() async {
    await db.close();
  });

  test('SyncEngine successful performSync flow', () async {
    final result = await syncEngine.performSync();
    expect(result.status, SyncStatus.success);
    expect(result.lastSyncedAt, isNotNull);

    final savedLastSynced = await syncEngine.getLastSyncedAt();
    expect(savedLastSynced, isNotNull);
  });

  test(
    'SyncEngine offline state handling when remote connection fails',
    () async {
      final failingEngine = SyncEngine(
        db: db,
        remoteProvider: FailingRemoteSyncProvider(),
      );
      final result = await failingEngine.performSync();
      expect(result.status, SyncStatus.offline);
      expect(result.errorMessage, contains('No active network connection'));
    },
  );

  test('SyncEngine auto-sync preference toggle persistence', () async {
    expect(await syncEngine.getAutoSyncEnabled(), true);
    await syncEngine.setAutoSyncEnabled(false);
    expect(await syncEngine.getAutoSyncEnabled(), false);
  });
}
