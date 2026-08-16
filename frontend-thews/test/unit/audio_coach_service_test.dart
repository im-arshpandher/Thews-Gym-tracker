import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/core/models/smartwatch_models.dart';
import 'package:thews/core/services/audio_coach_service.dart';
import 'package:thews/core/services/cadence_metronome_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async => null,
  );

  group('AudioCoachConfig & Serialization Tests', () {
    test('Default config has expected sensible endurance values', () {
      const config = AudioCoachConfig();
      expect(config.isVoiceEnabled, isTrue);
      expect(config.speechRate, equals(0.5));
      expect(config.splitIntervalMeters, equals(1000.0));
      expect(config.announceSplitPace, isTrue);
      expect(config.announceTotalDistance, isTrue);
      expect(config.announceElapsedTime, isTrue);
      expect(config.announceHeartRate, isTrue);
      expect(config.hrZoneAlertsEnabled, isTrue);
      expect(config.targetHrZone, isNull);
    });

    test('AudioCoachConfig JSON roundtrip serialization', () {
      const config = AudioCoachConfig(
        isVoiceEnabled: true,
        speechRate: 0.6,
        pitch: 1.1,
        volume: 0.9,
        splitIntervalMeters: 1609.34,
        announceSplitPace: true,
        announceTotalDistance: false,
        announceElapsedTime: true,
        announceHeartRate: true,
        announceCurrentPace: false,
        targetDistanceMeters: 5000.0,
        hrZoneAlertsEnabled: true,
        targetHrZone: HeartRateZoneType.fatBurn,
        hrAlertCooldownSeconds: 60,
      );

      final json = config.toJson();
      final restored = AudioCoachConfig.fromJson(json);

      expect(restored.isVoiceEnabled, isTrue);
      expect(restored.speechRate, equals(0.6));
      expect(restored.pitch, equals(1.1));
      expect(restored.volume, equals(0.9));
      expect(restored.splitIntervalMeters, equals(1609.34));
      expect(restored.announceTotalDistance, isFalse);
      expect(restored.announceCurrentPace, isFalse);
      expect(restored.targetDistanceMeters, equals(5000.0));
      expect(restored.targetHrZone, equals(HeartRateZoneType.fatBurn));
      expect(restored.hrAlertCooldownSeconds, equals(60));
    });

    test('AudioCoachConfig copyWith handles clear nullable fields', () {
      const config = AudioCoachConfig(
        targetDistanceMeters: 10000.0,
        targetHrZone: HeartRateZoneType.cardio,
      );

      final cleared = config.copyWith(
        clearTargetDistance: true,
        clearTargetHrZone: true,
      );

      expect(cleared.targetDistanceMeters, isNull);
      expect(cleared.targetHrZone, isNull);
    });
  });

  group('AudioCoach Voice Text Formatters Tests', () {
    test('formatPaceForSpeech formats seconds into readable voice text', () {
      // 4:55 /km -> 295 seconds
      final spokenPace = AudioCoachService.formatPaceForSpeech(295.0);
      expect(spokenPace, equals('4 minutes 55 seconds per kilometer'));

      // Exact whole minute (5:00 /km)
      final wholeMin = AudioCoachService.formatPaceForSpeech(300.0);
      expect(wholeMin, equals('5 minutes per kilometer'));

      // Invalid pace
      expect(AudioCoachService.formatPaceForSpeech(0.0), equals('pace unavailable'));
    });

    test('formatDurationForSpeech formats seconds into hours/minutes/seconds', () {
      expect(AudioCoachService.formatDurationForSpeech(45), equals('45 seconds'));
      expect(AudioCoachService.formatDurationForSpeech(1530), equals('25 minutes 30 seconds'));
      expect(AudioCoachService.formatDurationForSpeech(3665), contains('1 hours 1 minutes 5 seconds'));
    });

    test('formatDistanceForSpeech formats meters and kilometers', () {
      expect(AudioCoachService.formatDistanceForSpeech(500.0), equals('500 meters'));
      expect(AudioCoachService.formatDistanceForSpeech(5000.0), equals('5.0 kilometers'));
      expect(AudioCoachService.formatDistanceForSpeech(21097.5), equals('21 kilometers'));
    });
  });

  group('AudioCoachService Voice Split & Boundary Alerts Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('announceSplit constructs comprehensive voice sentence', () async {
      final service = AudioCoachService();
      await service.updateConfig(
        const AudioCoachConfig(
          targetDistanceMeters: 5000.0,
        ),
      );

      await service.announceSplit(
        splitIndex: 2,
        totalDistanceMeters: 2000.0,
        totalDurationSeconds: 600,
        splitPaceSecondsPerKm: 300.0,
        currentPaceSecondsPerKm: 295.0,
        currentHeartRateBpm: 152,
      );

      expect(service.state.lastAnnouncementText, isNotNull);
      final text = service.state.lastAnnouncementText!;
      expect(text, contains('Split 2 completed.'));
      expect(text, contains('Total distance: 2.0 kilometers.'));
      expect(text, contains('Total time: 10 minutes 0 seconds.'));
      expect(text, contains('Split pace: 5 minutes per kilometer.'));
      expect(text, contains('Current pace: 4 minutes 55 seconds per kilometer.'));
      expect(text, contains('Heart rate: 152 beats per minute.'));
      expect(text, contains('Target: 3.0 kilometers remaining.'));

      service.dispose();
    });

    test('announceSplit announces race distance goal achievement', () async {
      final service = AudioCoachService();
      await service.updateConfig(
        const AudioCoachConfig(
          targetDistanceMeters: 5000.0,
        ),
      );

      await service.announceSplit(
        splitIndex: 5,
        totalDistanceMeters: 5000.0,
        totalDurationSeconds: 1500,
        splitPaceSecondsPerKm: 300.0,
      );

      expect(service.state.lastAnnouncementText, contains('Target race distance achieved! Awesome work.'));
      service.dispose();
    });

    test('evaluateHeartRateZone triggers warning prompt when exceeding target zone', () async {
      final service = AudioCoachService();
      // Target Zone 2: Fat Burn (typically ~118-137 BPM for standard age 25)
      await service.updateConfig(
        const AudioCoachConfig(
          hrZoneAlertsEnabled: true,
          targetHrZone: HeartRateZoneType.fatBurn,
          hrAlertCooldownSeconds: 30,
        ),
      );

      final zone3 = const HeartRateZone(
        type: HeartRateZoneType.cardio,
        name: 'Zone 3: Cardio',
        minBpm: 138,
        maxBpm: 156,
        color: Color(0xFFFFD54F),
        description: 'Cardio',
      );

      await service.evaluateHeartRateZone(
        currentBpm: 155,
        currentZone: zone3,
      );

      expect(service.state.lastAnnouncementText, isNotNull);
      expect(service.state.lastAnnouncementText!, contains('Warning: Exiting Zone 2: Fat Burn. Current heart rate is 155 beats per minute. Ease your pace.'));

      service.dispose();
    });

    test('evaluateHeartRateZone respects cooldown debounce timer', () async {
      final service = AudioCoachService();
      await service.updateConfig(
        const AudioCoachConfig(
          hrZoneAlertsEnabled: true,
          targetHrZone: HeartRateZoneType.fatBurn,
          hrAlertCooldownSeconds: 60,
        ),
      );

      final zone3 = const HeartRateZone(
        type: HeartRateZoneType.cardio,
        name: 'Zone 3: Cardio',
        minBpm: 138,
        maxBpm: 156,
        color: Color(0xFFFFD54F),
        description: 'Cardio',
      );

      // First alert fires
      await service.evaluateHeartRateZone(currentBpm: 150, currentZone: zone3);
      final firstText = service.state.lastAnnouncementText;
      expect(firstText, isNotNull);

      // Immediate second call should be debounced within cooldown
      service.state = service.state.copyWith(clearLastAnnouncementText: true);
      await service.evaluateHeartRateZone(currentBpm: 152, currentZone: zone3);
      expect(service.state.lastAnnouncementText, isNull);

      service.dispose();
    });
  });

  group('CadenceMetronomeService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default 175 SPM and audioAndHaptic mode', () {
      final service = CadenceMetronomeService();
      expect(service.state.isPlaying, isFalse);
      expect(service.state.targetBpm, equals(175));
      expect(service.state.feedbackMode, equals(MetronomeFeedbackMode.audioAndHaptic));
      expect(service.state.subdivision, equals(MetronomeSubdivision.everyStep));
      service.dispose();
    });

    test('setBpm clamps SPM between 120 and 220', () {
      final service = CadenceMetronomeService();
      service.setBpm(100);
      expect(service.state.targetBpm, equals(120));

      service.setBpm(250);
      expect(service.state.targetBpm, equals(220));

      service.setBpm(180);
      expect(service.state.targetBpm, equals(180));
      service.dispose();
    });

    test('start, stop and toggle state transitions', () {
      final service = CadenceMetronomeService();
      expect(service.state.isPlaying, isFalse);

      service.start();
      expect(service.state.isPlaying, isTrue);

      service.stop();
      expect(service.state.isPlaying, isFalse);

      service.toggle();
      expect(service.state.isPlaying, isTrue);

      service.toggle();
      expect(service.state.isPlaying, isFalse);
      service.dispose();
    });

    test('AudioCoachService updateConfig persists and restores all preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service1 = AudioCoachService();
      await Future.delayed(const Duration(milliseconds: 50));

      const customConfig = AudioCoachConfig(
        isVoiceEnabled: false,
        speechRate: 0.7,
        pitch: 1.1,
        volume: 0.6,
        splitIntervalMeters: 500.0,
        announceSplitPace: false,
        announceTotalDistance: true,
        announceElapsedTime: false,
        announceHeartRate: true,
        announceCurrentPace: false,
        targetDistanceMeters: 5000.0,
        hrZoneAlertsEnabled: true,
        targetHrZone: HeartRateZoneType.anaerobic,
        hrAlertCooldownSeconds: 30,
      );

      await service1.updateConfig(customConfig);
      service1.dispose();

      // Re-instantiate service to verify full restoration
      final service2 = AudioCoachService();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(service2.state.config.isVoiceEnabled, isFalse);
      expect(service2.state.config.speechRate, equals(0.7));
      expect(service2.state.config.pitch, equals(1.1));
      expect(service2.state.config.volume, equals(0.6));
      expect(service2.state.config.splitIntervalMeters, equals(500.0));
      expect(service2.state.config.announceSplitPace, isFalse);
      expect(service2.state.config.announceTotalDistance, isTrue);
      expect(service2.state.config.announceElapsedTime, isFalse);
      expect(service2.state.config.announceHeartRate, isTrue);
      expect(service2.state.config.announceCurrentPace, isFalse);
      expect(service2.state.config.targetDistanceMeters, equals(5000.0));
      expect(service2.state.config.targetHrZone, equals(HeartRateZoneType.anaerobic));
      expect(service2.state.config.hrAlertCooldownSeconds, equals(30));

      service2.dispose();
    });

    test('CadenceMetronomeService settings persist across app reboots', () async {
      SharedPreferences.setMockInitialValues({});
      final service1 = CadenceMetronomeService();
      await Future.delayed(const Duration(milliseconds: 50));

      service1.setBpm(188);
      service1.setFeedbackMode(MetronomeFeedbackMode.hapticOnly);
      service1.setSubdivision(MetronomeSubdivision.everyFourthStep);
      service1.setVolume(0.45);
      await Future.delayed(const Duration(milliseconds: 50));
      service1.dispose();

      // Re-instantiate service to verify restoration
      final service2 = CadenceMetronomeService();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(service2.state.targetBpm, equals(188));
      expect(service2.state.feedbackMode, equals(MetronomeFeedbackMode.hapticOnly));
      expect(service2.state.subdivision, equals(MetronomeSubdivision.everyFourthStep));
      expect(service2.state.volume, equals(0.45));

      service2.dispose();
    });
  });
}
