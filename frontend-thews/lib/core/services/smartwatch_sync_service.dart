import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/smartwatch_models.dart';

class SmartwatchState {
  final SmartwatchConnectionStatus status;
  final SmartwatchDevice? device;
  final int currentBpm;
  final HeartRateZone currentZone;
  final double activeCaloriesBurned;
  final List<HeartRateSample> sessionSamples;
  final List<DiscoveredBleDevice> discoveredDevices;
  final bool isScanning;
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
    this.discoveredDevices = const [],
    this.isScanning = false,
    this.isSimulated = false,
    this.lastMessage,
  });

  SmartwatchState copyWith({
    SmartwatchConnectionStatus? status,
    SmartwatchDevice? device,
    int? currentBpm,
    HeartRateZone? currentZone,
    double? activeCaloriesBurned,
    List<HeartRateSample>? sessionSamples,
    List<DiscoveredBleDevice>? discoveredDevices,
    bool? isScanning,
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
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isScanning: isScanning ?? this.isScanning,
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
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSubscription;
  StreamSubscription<List<int>>? _hrDataSubscription;
  BluetoothDevice? _activeBleDevice;
  final Random _random = Random();

  DateTime? _lastSampleTime;

  SmartwatchSyncService() : super(const SmartwatchState()) {
    _initChannelHandler();
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

  /// Starts Bluetooth Low Energy scan for Heart Rate sensors and smartwatches.
  Future<void> startBleScan() async {
    state = state.copyWith(
      isScanning: true,
      status: SmartwatchConnectionStatus.scanning,
      discoveredDevices: [],
      lastMessage: 'Scanning for Heart Rate monitors & smartwatches...',
    );

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        state = state.copyWith(
          isScanning: false,
          status: SmartwatchConnectionStatus.disconnected,
          lastMessage: 'Bluetooth is not supported on this device',
        );
        return;
      }

      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final Map<String, DiscoveredBleDevice> map = {};
        for (final r in results) {
          final advName = r.advertisementData.advName.trim();
          final devName = r.device.platformName.trim();
          final displayName = advName.isNotEmpty ? advName : (devName.isNotEmpty ? devName : 'BLE Heart Rate Sensor');
          final hasHrService = r.advertisementData.serviceUuids.any(
            (u) => u.toString().toLowerCase().contains('180d'),
          );

          // Only list devices with names or heart rate service
          if (displayName.isNotEmpty && displayName != 'N/A') {
            map[r.device.remoteId.str] = DiscoveredBleDevice(
              id: r.device.remoteId.str,
              name: displayName,
              rssi: r.rssi,
              isHeartRateService: hasHrService,
            );
          }
        }

        state = state.copyWith(discoveredDevices: map.values.toList());
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid('180D')],
        timeout: const Duration(seconds: 12),
      );

      // If no devices with explicit service filter, fallback to general scan
      if (state.discoveredDevices.isEmpty) {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      }
    } catch (e) {
      final msg = e.toString().contains('MissingPluginException')
          ? 'Bluetooth plugin requires a full app restart. Please stop and re-run the app in your terminal, or use the Simulator below.'
          : 'BLE scan failed: $e';
      state = state.copyWith(
        isScanning: false,
        status: SmartwatchConnectionStatus.disconnected,
        lastMessage: msg,
      );
    }
  }

  Future<void> stopBleScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('BLE stopScan notice: $e');
    }
    state = state.copyWith(isScanning: false);
  }

  /// Connects to a real physical BLE device by its ID.
  Future<void> connectBleDevice(String deviceId, {String? deviceName}) async {
    await stopBleScan();
    state = state.copyWith(
      status: SmartwatchConnectionStatus.connecting,
      isSimulated: false,
      lastMessage: 'Connecting to ${deviceName ?? deviceId}...',
    );

    try {
      final device = BluetoothDevice.fromId(deviceId);
      _activeBleDevice = device;

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _deviceConnectionSubscription?.cancel();
      _deviceConnectionSubscription = device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected) {
          disconnectSmartwatch();
        }
      });

      // Discover GATT Services
      final services = await device.discoverServices();
      bool hrFound = false;
      int batteryLevel = 88;

      for (final service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        // 1. Heart Rate GATT Service (0x180D)
        if (serviceUuid.contains('180d')) {
          for (final char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            // Heart Rate Measurement (0x2A37)
            if (charUuid.contains('2a37')) {
              hrFound = true;
              await char.setNotifyValue(true);
              _hrDataSubscription?.cancel();
              _hrDataSubscription = char.lastValueStream.listen((data) {
                final bpm = HeartRateSample.parseGattBytes(data);
                if (bpm > 0) {
                  _recordHeartRate(bpm);
                }
              });
            }
          }
        }

        // 2. Battery Service (0x180F)
        if (serviceUuid.contains('180f')) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains('2a19')) {
              try {
                final val = await char.read();
                if (val.isNotEmpty) {
                  batteryLevel = val.first;
                }
              } catch (e) {
                debugPrint('Battery level read notice: $e');
              }
            }
          }
        }
      }

      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        isSimulated: false,
        device: SmartwatchDevice(
          id: deviceId,
          name: deviceName ?? (device.platformName.isNotEmpty ? device.platformName : 'Heart Rate Monitor'),
          platform: SmartwatchPlatform.bleHeartRate,
          batteryLevelPercent: batteryLevel,
          isConnected: true,
          lastSyncTime: DateTime.now(),
        ),
        lastMessage: hrFound
            ? 'Connected & streaming live heart rate telemetry'
            : 'Connected (Awaiting heart rate GATT stream)',
      );
    } catch (e) {
      final msg = e.toString().contains('MissingPluginException')
          ? 'Bluetooth plugin requires a full app restart. Please re-run the app, or use the Simulator below.'
          : 'Failed to connect: $e';
      state = state.copyWith(
        status: SmartwatchConnectionStatus.disconnected,
        lastMessage: msg,
      );
    }
  }

  /// Connects to a companion smartwatch or activates the companion simulation engine.
  Future<void> connectSmartwatch({bool simulated = false, int baseBpm = 135}) async {
    state = state.copyWith(
      status: SmartwatchConnectionStatus.connecting,
      isSimulated: simulated,
      lastMessage: simulated ? 'Connecting to Simulated Sensor...' : 'Connecting to wearable...',
    );

    if (simulated) {
      await Future.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        device: SmartwatchDevice(
          id: 'thews_simulated_sensor',
          name: 'Polar H10 / Smartwatch (Simulated)',
          platform: SmartwatchPlatform.simulated,
          batteryLevelPercent: 95,
          isConnected: true,
          lastSyncTime: DateTime.now(),
        ),
        lastMessage: 'Connected to Workout Sensor Simulation',
      );
      _startHeartRateSimulation(baseBpm: baseBpm);
    } else {
      await startBleScan();
    }
  }

  void disconnectSmartwatch() {
    _simulationHeartRateTimer?.cancel();
    _simulationHeartRateTimer = null;
    _hrDataSubscription?.cancel();
    _hrDataSubscription = null;
    _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription = null;
    try {
      _activeBleDevice?.disconnect();
    } catch (e) {
      debugPrint('BLE disconnect notice: $e');
    }
    _activeBleDevice = null;

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
      await Future.delayed(const Duration(milliseconds: 150));
      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        device: state.device?.copyWith(lastSyncTime: DateTime.now()),
        lastMessage: 'Synced with ${state.device?.name}',
      );
    } catch (e) {
      debugPrint('Workout payload sync notice: $e');
      state = state.copyWith(
        status: SmartwatchConnectionStatus.connected,
        lastMessage: 'Payload updated',
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
    final now = DateTime.now();
    final zone = HeartRateZone.getZoneForBpm(bpm);
    final sample = HeartRateSample(
      bpm: bpm,
      timestamp: now,
      zone: zone.type,
    );

    // Calculate real metabolic calories burned using Keytel energy formula
    double addedCalories = 0.0;
    if (_lastSampleTime != null) {
      final elapsedMinutes = now.difference(_lastSampleTime!).inMilliseconds / 60000.0;
      if (elapsedMinutes > 0 && elapsedMinutes < 1.0) {
        final caloriesPerMinute = HeartRateSample.calculateKeytelCaloriesPerMinute(
          bpm: bpm,
          age: 25,
          weightKg: 70.0,
        );
        addedCalories = caloriesPerMinute * elapsedMinutes;
      }
    }
    _lastSampleTime = now;

    final updatedSamples = List<HeartRateSample>.from(state.sessionSamples)..add(sample);
    if (updatedSamples.length > 600) {
      updatedSamples.removeAt(0);
    }

    state = state.copyWith(
      currentBpm: bpm,
      currentZone: zone,
      activeCaloriesBurned: state.activeCaloriesBurned + addedCalories,
      sessionSamples: updatedSamples,
    );
  }

  void _startHeartRateSimulation({int baseBpm = 135}) {
    _simulationHeartRateTimer?.cancel();
    int currentSimBpm = baseBpm;
    _lastSampleTime = DateTime.now();

    _simulationHeartRateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != SmartwatchConnectionStatus.connected) return;
      final variance = _random.nextInt(5) - 2;
      currentSimBpm = (currentSimBpm + variance).clamp(80, 185);
      _recordHeartRate(currentSimBpm);
    });
  }

  void resetSessionBiometrics() {
    _lastSampleTime = null;
    state = state.copyWith(
      activeCaloriesBurned: 0.0,
      sessionSamples: [],
    );
  }

  @override
  void dispose() {
    _simulationHeartRateTimer?.cancel();
    _scanSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
    _hrDataSubscription?.cancel();
    try {
      _activeBleDevice?.disconnect();
    } catch (e) {
      debugPrint('BLE active device disconnect in dispose: $e');
    }
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
