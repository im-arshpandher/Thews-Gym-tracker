import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/services/gps_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late RunTrackingNotifier notifier;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator_android'),
      (methodCall) async => null,
    );

    database = AppDatabase.forTesting(NativeDatabase.memory());
    notifier = RunTrackingNotifier(database);
  });

  tearDown(() async {
    notifier.dispose();
    await database.close();
  });

  group('RunTrackingNotifier Unit Tests', () {
    test('initial state defaults', () {
      expect(notifier.state.isTracking, false);
      expect(notifier.state.isPaused, false);
      expect(notifier.state.durationSeconds, 0);
      expect(notifier.state.distanceMeters, 0.0);
      expect(notifier.state.activityType, 'run');
    });

    test('setActivityType updates activity type correctly', () {
      notifier.setActivityType('cycle');
      expect(notifier.state.activityType, 'cycle');

      notifier.setActivityType('walk');
      expect(notifier.state.activityType, 'walk');
    });

    test('pauseTracking and resumeTracking update state flags', () async {
      await notifier.startTracking(activityType: 'run');
      expect(notifier.state.isTracking, true);
      expect(notifier.state.isPaused, false);

      notifier.pauseTracking();
      expect(notifier.state.isTracking, true);
      expect(notifier.state.isPaused, true);

      notifier.resumeTracking();
      expect(notifier.state.isTracking, true);
      expect(notifier.state.isPaused, false);

      notifier.stopTracking();
      expect(notifier.state.isTracking, false);
      expect(notifier.state.isPaused, false);
    });

    test('finishAndSaveActivity discards activity under 10 meters', () async {
      await notifier.startTracking(activityType: 'run');
      final resultId = await notifier.finishAndSaveActivity();

      expect(resultId, isNull);
      expect(notifier.state.isTracking, false);
    });
  });
}
