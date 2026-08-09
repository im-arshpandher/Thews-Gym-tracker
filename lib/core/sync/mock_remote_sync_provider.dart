import 'dart:async';
import 'sync_provider_interface.dart';

class MockRemoteSyncProvider implements RemoteSyncProvider {
  bool _authenticated = false;
  SyncPayload? _remoteStorage;

  @override
  String get providerName => 'Mock Cloud Provider';

  @override
  bool get isAuthenticated => _authenticated;

  @override
  Future<bool> authenticate(String apiKeyOrToken) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (apiKeyOrToken.isNotEmpty) {
      _authenticated = true;
      return true;
    }
    return false;
  }

  @override
  Future<void> signOut() async {
    _authenticated = false;
  }

  @override
  Future<bool> testConnection() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<SyncPayload> fetchRemoteChanges(DateTime? lastSyncedAt) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _remoteStorage ?? SyncPayload(timestamp: DateTime.now());
  }

  @override
  Future<bool> pushLocalChanges(SyncPayload payload) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _remoteStorage = payload;
    return true;
  }
}
