import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/smartwatch_models.dart';
import '../../../../core/services/smartwatch_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class SmartwatchPairingSheet extends ConsumerStatefulWidget {
  const SmartwatchPairingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SmartwatchPairingSheet(),
    );
  }

  @override
  ConsumerState<SmartwatchPairingSheet> createState() =>
      _SmartwatchPairingSheetState();
}

class _SmartwatchPairingSheetState
    extends ConsumerState<SmartwatchPairingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedSimBpm = 138;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Automatically trigger a BLE scan if disconnected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final status = ref.read(smartwatchServiceProvider).status;
      if (status == SmartwatchConnectionStatus.disconnected) {
        ref.read(smartwatchServiceProvider.notifier).startBleScan();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final smartwatchState = ref.watch(smartwatchServiceProvider);
    final smartwatchNotifier = ref.read(smartwatchServiceProvider.notifier);

    final isConnected =
        smartwatchState.status == SmartwatchConnectionStatus.connected;
    final isScanning = smartwatchState.isScanning;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.lightSurfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.3)
              : AppColors.lightOutline.withValues(alpha: 0.3),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkOutline.withValues(alpha: 0.4)
                        : AppColors.lightOutline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HEART RATE & WATCH PAIRING',
                          style: AppTypography.sectionTitle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Connect BLE chest straps, Polar, Garmin, Wear OS & Apple Watch',
                          style: AppTypography.tinyLabel(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Active Connection Card
              if (isConnected && smartwatchState.device != null) ...[
                _buildConnectedDeviceCard(
                  context,
                  smartwatchState,
                  smartwatchNotifier,
                  isDark,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Scan & Discovered Devices Section
              if (!isConnected) ...[
                // BLE Radar & Status Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutline.withValues(alpha: 0.3)
                          : AppColors.lightOutline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (isScanning)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryVolt,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.bluetooth_searching,
                                  size: 20,
                                  color: AppColors.primaryVolt,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                isScanning
                                    ? 'SCANNING FOR BLUETOOTH SENSORS...'
                                    : 'NEARBY SENSORS',
                                style: AppTypography.bodySm(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: isScanning
                                ? () => smartwatchNotifier.stopBleScan()
                                : () => smartwatchNotifier.startBleScan(),
                            icon: Icon(
                              isScanning ? Icons.stop : Icons.refresh,
                              size: 16,
                            ),
                            label: Text(
                              isScanning ? 'STOP' : 'SCAN',
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        smartwatchState.lastMessage ??
                            'Make sure your heart rate monitor or smartwatch is turned on and in pairing mode.',
                        style: AppTypography.tinyLabel(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Discovered Devices List
                if (smartwatchState.discoveredDevices.isNotEmpty) ...[
                  Text(
                    'DISCOVERED DEVICES (${smartwatchState.discoveredDevices.length})',
                    style: AppTypography.labelCaps(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  const SizedBox(height: 8),
                  ...smartwatchState.discoveredDevices.map(
                    (device) => _buildDiscoveredDeviceTile(
                      device,
                      smartwatchNotifier,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else if (!isScanning) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.darkSurfaceContainer
                              : AppColors.lightSurfaceContainer)
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No Bluetooth sensors detected yet. Tap SCAN to search.',
                        style: AppTypography.tinyLabel(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Simulation / Indoor Test Card
                _buildSimulationSection(smartwatchNotifier, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard(
    BuildContext context,
    SmartwatchState state,
    SmartwatchSyncService notifier,
    bool isDark,
  ) {
    final dev = state.device!;
    final zone = state.currentZone;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: zone.color.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: zone.color.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Title & Battery
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      dev.platform == SmartwatchPlatform.bleHeartRate
                          ? Icons.bluetooth_connected
                          : Icons.watch,
                      color: zone.color,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dev.name,
                            style: AppTypography.sectionTitle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ).copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            state.isSimulated
                                ? 'TEST SIMULATOR'
                                : 'LIVE BLUETOOTH GATT',
                            style: AppTypography.tinyLabel(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ).copyWith(fontSize: 10),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : AppColors.lightSurfaceContainer)
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.battery_std,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${dev.batteryLevelPercent}%',
                      style: AppTypography.tinyLabel(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Live BPM Display with Pulse Waveform
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.12);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: zone.color.withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: zone.color,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          state.currentBpm > 0 ? '${state.currentBpm}' : '--',
                          style: AppTypography.displayHero(
                            color: zone.color,
                          ).copyWith(fontSize: 36, height: 1.0),
                          maxLines: 1,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'BPM',
                          style: AppTypography.tinyLabel(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ).copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: zone.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        zone.name,
                        style: TextStyle(
                          color: zone.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${state.activeCaloriesBurned.toStringAsFixed(1)} KCAL',
                    style: AppTypography.sectionTitle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ).copyWith(fontSize: 16),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  Text(
                    'CALORIES BURNED',
                    style: AppTypography.tinyLabel(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Disconnect Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => notifier.disconnectSmartwatch(),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text(
                'DISCONNECT SENSOR',
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDeviceTile(
    DiscoveredBleDevice device,
    SmartwatchSyncService notifier,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.2)
              : AppColors.lightOutline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryVolt.withValues(alpha: 0.15)
                  : AppColors.lightPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth,
              size: 20,
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: AppTypography.sectionTitle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ).copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID: ${device.id} • Signal: ${device.rssi} dBm',
                  style: AppTypography.tinyLabel(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: isDark
                  ? AppColors.primaryVolt
                  : AppColors.lightPrimary,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
            ),
            onPressed: () => notifier.connectBleDevice(
              device.id,
              deviceName: device.name,
            ),
            child: const Text('CONNECT', maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationSection(
    SmartwatchSyncService notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.2)
              : AppColors.lightOutline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 20,
                color: AppColors.chestAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'TESTING / SIMULATED SENSOR',
                style: AppTypography.bodySm(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If you do not have a physical Bluetooth chest strap or watch nearby, launch the simulated heart rate engine with custom training zone pacing.',
            style: AppTypography.tinyLabel(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Preset intensity buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSimChip('WARMUP 115', 115, isDark),
                const SizedBox(width: 6),
                _buildSimChip('AEROBIC 138', 138, isDark),
                const SizedBox(width: 6),
                _buildSimChip('TEMPO 158', 158, isDark),
                const SizedBox(width: 6),
                _buildSimChip('REDLINE 176', 176, isDark),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: isDark
                    ? AppColors.primaryVolt
                    : AppColors.lightPrimary,
                foregroundColor:
                    isDark ? AppColors.darkBackground : Colors.white,
              ),
              onPressed: () {
                notifier.connectSmartwatch(
                  simulated: true,
                  baseBpm: _selectedSimBpm,
                );
              },
              icon: const Icon(Icons.play_circle_outline, size: 20),
              label: const Text(
                'START SIMULATED SENSOR',
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimChip(String label, int bpm, bool isDark) {
    final isSelected = _selectedSimBpm == bpm;
    return ChoiceChip(
      label: Text(label, maxLines: 1, softWrap: false),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedSimBpm = bpm),
      selectedColor: isDark
          ? AppColors.primaryVolt.withValues(alpha: 0.25)
          : AppColors.lightPrimary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
            : (isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary),
      ),
    );
  }
}
