import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/smartwatch_models.dart';

class SmartwatchState {
  final SmartwatchConnectionStatus status;
  final SmartwatchDevice? device;
  final int currentBpm;
  final HeartRateZone currentZone;
  final double activeCaloriesBurned;
  final List<HeartRateSample> sessionSamples;
  final bool isSimulated;
  final String? lastMessage;

  const SmartwatchState({
    this.status = SmartwatchConnectionStatus.disconnected,
    this.device,
    this.currentBpm = 0,
    this.currentZone = const HeartRateZone(
      type: HeartRateZoneType.warmup,
      name: 'Zone 1: Warmup',
      minBpm: 90,
      maxBpm: 120,
      color: Color(0xFF64B5F6),
      description: 'Resting / Warmup',
    ),
    this.activeCaloriesBurned = 0.0,
    this.sessionSamples = const [],
    this.isSimulated = true,
    this.lastMessage,
  });

  SmartwatchState copyWith({
    SmartwatchConnectionStatus? status,
    SmartwatchDevice? device,
    int? currentBpm,
    HeartRateZone? currentZone,
    double? activeCaloriesBurned,
    List<HeartRateSample>? sessionSamples,
    bool? isSimulated,
    String? lastMessage,
  }) {
    return SmartwatchState(
      status: status ?? this.status,
      device: device ?? this.device,
      currentBpm: currentBpm ?? this.currentBpm,
      currentZone: currentZone ?? this.currentZone,
      activeCaloriesBurned: activeCaloriesBurned ?? this.activeCaloriesBurned,
      sessionSamples: sessionSamples ?? this.sessionSamples,
      isSimulated: isSimulated ?? this.isSimulated,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}

class SmartwatchSyncService extends StateNotifier<SmartwatchState> {
  static const MethodChannel _channel = MethodChannel('com.thews.app/wearable');

  final StreamController<WristSetAction> _wristActionController =
      StreamController<WristSetAction>.broadcast();
  Stream<WristSetAction> get wristActionStream => _wristActionController.stream;

  Timer? _simulationHeartRateTimer;
  final Random _random = Random();

  SmartwatchSyncService() : super(const SmartwatchState()) {
    _initChannelHandler();
    // Default to a ready simulated device for local convenience
    _setupDefaultDevice();
  }

  void _setupDefaultDevice() {
    state = state.copyWith(
      device: const SmartwatchDevice(
        id: 'thews_watch_01',
        name: 'Galaxy Watch / Apple Watch',
        platform: SmartwatchPlatform.simulated,
        batteryLevelPercent: 92,
        isConnected: false,
      ),
    );
  }

  void _initChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onHeartRateReceived':
          final bpm = call.arguments['bpm'] as int? ?? 70;
          _recordHeartRate(bpm);
          break;
        case 'onWristSetCompleted':
          final action = WristSetAction(
            actionType: WristActionType.completeSet,
            exerciseName: call.arguments['exerciseName'] as String? ?? '',
            setIndex: call.arguments['setIndex'] as int? ?? 0,
            weightKg: (call.arguments['weightKg'] as num?)?.toDouble(),
            reps: call.arguments['reps'] as int?,
            timestamp: DateTime.now(),
          );
          _wristActionController.add(action);
          break;
        case 'onDeviceConnectionChanged':
          final isConnected = call.arguments['isConnected'] as bool? ?? false;
          final deviceName = call.arguments['deviceName'] as String? ?? 'Smartwatch';
          if (isConnected) {
            state = state.copyWith(
              status: SmartwatchConnectionStatus.connected,
              device: SmartwatchDevice(
                id: 'wearable_device',
                name: deviceName,
                platform: SmartwatchPlatform.wearOs,
                isConnected: true,
                lastSyncTime: DateTime.now(),
              ),
              lastMessage: 'Connected to $deviceName',
            );
          } else {
            state = state.copyWith(
              status: SmartwatchConnectionStatus.disconnected,
              device: state.device?.copyWith(isConnected: false),
              lastMessage: 'Disconnected from smartwatch',
            );
          }
          break;
      }
    });
  }

  /// Connects to a smartwatch or activates the companion simulation engine.
  Future<void> connectSmartwatch({bool simulated = false}) async {
    state = state.copyWith(
      status: SmartwatchConnectionStatus.connecting,
      isSimulated: simulated,
      lastMessage: 'Connecting to wearable...',
    );

    if (simulated) {
      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        device: state.device?.copyWith(
          isConnected: true,
          lastSyncTime: DateTime.now(),
        ),
        lastMessage: 'Connected to Simulated Companion',
      );
      _startHeartRateSimulation();
    } else {
      try {
        final result = await _channel.invokeMethod<bool>('connectDevice');
        if (result == true) {
          state = state.copyWith(
            status: SmartwatchConnectionStatus.connected,
            isSimulated: false,
            device: state.device?.copyWith(
              isConnected: true,
              lastSyncTime: DateTime.now(),
            ),
            lastMessage: 'Connected to native watch companion',
          );
        } else {
          // Fallback to simulation if native wearable is not physically paired
          connectSmartwatch(simulated: true);
        }
      } catch (_) {
        // Fallback gracefully on desktop or non-native platforms
        connectSmartwatch(simulated: true);
      }
    }
  }

  void disconnectSmartwatch() {
    _simulationHeartRateTimer?.cancel();
    _simulationHeartRateTimer = null;
    state = state.copyWith(
      status: SmartwatchConnectionStatus.disconnected,
      currentBpm: 0,
      device: state.device?.copyWith(isConnected: false),
      lastMessage: 'Wearable disconnected',
    );
  }

  /// Pushes active workout state payload to wrist companion.
  Future<void> syncWorkoutPayload(SmartwatchWorkoutPayload payload) async {
    if (state.status != SmartwatchConnectionStatus.connected) return;

    state = state.copyWith(
      status: SmartwatchConnectionStatus.syncing,
      lastMessage: 'Transmitting payload to wrist...',
    );

    try {
      if (!state.isSimulated) {
        await _channel.invokeMethod('sendWorkoutPayload', payload.toMap());
      }
      await Future.delayed(const Duration(milliseconds: 200));
      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        device: state.device?.copyWith(lastSyncTime: DateTime.now()),
        lastMessage: 'Synced with ${state.device?.name}',
      );
    } catch (_) {
      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        lastMessage: 'Payload sent to simulated watch',
      );
    }
  }

  /// Injects a wrist-completed set event (useful for testing and watch communication).
  void triggerSimulatedWristSetComplete({
    required String exerciseName,
    required int setIndex,
    double? weightKg,
    int? reps,
  }) {
    final action = WristSetAction(
      actionType: WristActionType.completeSet,
      exerciseName: exerciseName,
      setIndex: setIndex,
      weightKg: weightKg,
      reps: reps,
      timestamp: DateTime.now(),
    );
    _wristActionController.add(action);
  }

  void _recordHeartRate(int bpm) {
    final zone = HeartRateZone.getZoneForBpm(bpm);
    final sample = HeartRateSample(
      bpm: bpm,
      timestamp: DateTime.now(),
      zone: zone.type,
    );

    // Approximate active calories: standard average metabolic burn calculation
    final newCalories = state.activeCaloriesBurned + (bpm > 100 ? (bpm / 120.0) * 0.12 : 0.04);

    final updatedSamples = List<HeartRateSample>.from(state.sessionSamples)..add(sample);
    if (updatedSamples.length > 500) {
      updatedSamples.removeAt(0);
    }

    state = state.copyWith(
      currentBpm: bpm,
      currentZone: zone,
      activeCaloriesBurned: newCalories,
      sessionSamples: updatedSamples,
    );
  }

  void _startHeartRateSimulation() {
    _simulationHeartRateTimer?.cancel();
    // Simulate natural heart rate drift between 110 and 165 BPM during a workout session
    _simulationHeartRateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state.status != SmartwatchConnectionStatus.connected) return;
      int baseBpm = state.currentBpm;
      if (baseBpm == 0) baseBpm = 125;
      final variance = _random.nextInt(7) - 3;
      final nextBpm = (baseBpm + variance).clamp(85, 178);
      _recordHeartRate(nextBpm);
    });
  }

  void resetSessionBiometrics() {
    state = state.copyWith(
      activeCaloriesBurned: 0.0,
      sessionSamples: [],
    );
  }

  @override
  void dispose() {
    _simulationHeartRateTimer?.cancel();
    _wristActionController.close();
    super.dispose();
  }
}

final smartwatchServiceProvider =
    StateNotifierProvider<SmartwatchSyncService, SmartwatchState>((ref) {
  return SmartwatchSyncService();
});

final wristActionStreamProvider = StreamProvider<WristSetAction>((ref) {
  final service = ref.watch(smartwatchServiceProvider.notifier);
  return service.wristActionStream;
});
