import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/tile_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/challenge_models.dart';
import '../domain/loop_route_generator.dart';
import 'challenges_provider.dart';

class CreateCustomChallengeScreen extends ConsumerStatefulWidget {
  final List<LatLng>? initialWaypoints;

  const CreateCustomChallengeScreen({
    super.key,
    this.initialWaypoints,
  });

  @override
  ConsumerState<CreateCustomChallengeScreen> createState() =>
      _CreateCustomChallengeScreenState();
}

class _CreateCustomChallengeScreenState
    extends ConsumerState<CreateCustomChallengeScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _animController;
  final List<LatLng> _waypoints = [];
  final _titleController = TextEditingController(text: 'My Custom Street Loop');
  final _descriptionController = TextEditingController(
    text: 'Custom athlete-plotted route traversing through local neighborhood blocks.',
  );
  late final TextEditingController _localityController;
  ChallengeDifficulty _selectedDifficulty = ChallengeDifficulty.medium;
  double _calculatedDistanceMeters = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialWaypoints != null && widget.initialWaypoints!.isNotEmpty) {
      _waypoints.addAll(widget.initialWaypoints!);
      _recalculateDistance();
    }
    final currentLocality = ref.read(challengesProvider).localityName;
    _localityController = TextEditingController(text: currentLocality);
  }

  @override
  void dispose() {
    _animController?.stop();
    _animController?.dispose();
    _animController = null;
    _mapController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  void _animatedMapMove(
    LatLng destLocation,
    double destZoom, {
    Duration duration = const Duration(milliseconds: 650),
    Curve curve = Curves.fastOutSlowIn,
  }) {
    _animController?.stop();
    _animController?.dispose();
    _animController = null;

    final camera = _mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );
    _animController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: curve,
    );

    controller.addListener(() {
      try {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      } catch (e) {
        debugPrint('Custom challenge map move notice: $e');
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (_animController == controller) {
          controller.dispose();
          _animController = null;
        }
      }
    });

    controller.forward();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _waypoints.add(point);
      _recalculateDistance();
    });
  }

  void _undoLastPoint() {
    if (_waypoints.isNotEmpty) {
      setState(() {
        _waypoints.removeLast();
        _recalculateDistance();
      });
    }
  }

  void _clearRoute() {
    if (_waypoints.isNotEmpty) {
      setState(() {
        _waypoints.clear();
        _calculatedDistanceMeters = 0.0;
      });
    }
  }

  void _closeLoop() {
    if (_waypoints.length >= 2) {
      final first = _waypoints.first;
      final last = _waypoints.last;
      if (first.latitude != last.latitude || first.longitude != last.longitude) {
        setState(() {
          _waypoints.add(first);
          _recalculateDistance();
        });
      }
    }
  }

  void _recalculateDistance() {
    _calculatedDistanceMeters =
        LoopRouteGenerator.calculateTotalRouteDistance(_waypoints);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = (currentZoom + 1.0).clamp(3.0, 19.0);
    _animatedMapMove(
      _mapController.camera.center,
      nextZoom,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = (currentZoom - 1.0).clamp(3.0, 19.0);
    _animatedMapMove(
      _mapController.camera.center,
      nextZoom,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _centerOnUser() {
    final userLoc = ref.read(challengesProvider).userLocation;
    _animatedMapMove(userLoc, 15.0);
  }

  int _calculateDynamicXp() {
    if (_calculatedDistanceMeters < 100) return 100;
    final km = _calculatedDistanceMeters / 1000.0;
    final multiplier = switch (_selectedDifficulty) {
      ChallengeDifficulty.easy => 120,
      ChallengeDifficulty.medium => 150,
      ChallengeDifficulty.hard => 200,
    };
    return (km * multiplier).round().clamp(100, 2500);
  }

  TrophyTier _getTrophyTierForDifficulty(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return TrophyTier.bronze;
      case ChallengeDifficulty.medium:
        return TrophyTier.silver;
      case ChallengeDifficulty.hard:
        return TrophyTier.gold;
    }
  }

  Future<void> _saveChallenge() async {
    if (_waypoints.length < 2 || _calculatedDistanceMeters < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please plot at least 2 waypoints on the map (min 50m distance).',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? 'Custom ${_calculatedDistanceMeters >= 1000 ? "${(_calculatedDistanceMeters / 1000).toStringAsFixed(1)}K" : "${_calculatedDistanceMeters.round()}M"} Circuit'
        : _titleController.text.trim();

    final locality = _localityController.text.trim().isEmpty
        ? ref.read(challengesProvider).localityName
        : _localityController.text.trim();

    final xp = _calculateDynamicXp();
    final tier = _getTrophyTierForDifficulty(_selectedDifficulty);
    final id = 'challenge_custom_${DateTime.now().millisecondsSinceEpoch}';

    final customChallenge = LocalChallenge(
      id: id,
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? 'Custom plotted route in $locality.'
          : _descriptionController.text.trim(),
      difficulty: _selectedDifficulty,
      targetDistanceMeters: _calculatedDistanceMeters,
      localityName: locality,
      loopWaypoints: List.from(_waypoints),
      isDaily: false,
      isCustom: true,
      trophyReward: TrophyBadge(
        id: 'trophy_custom_${DateTime.now().millisecondsSinceEpoch}',
        title: '$title Master',
        description: 'Conquered your custom plotted route "$title".',
        tier: tier,
        iconName: 'trophy_${tier.name}',
        category: _selectedDifficulty.name,
        xpReward: xp,
      ),
    );

    await ref
        .read(challengesProvider.notifier)
        .addCustomChallenge(customChallenge);

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Custom challenge "$title" created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(challengesProvider);
    final xp = _calculateDynamicXp();
    final isValid = _waypoints.length >= 2 && _calculatedDistanceMeters >= 50;

    return Scaffold(
      body: Stack(
        children: [
          // Interactive Map Drawing Canvas
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: state.userLocation,
                initialZoom: 15.0,
                onTap: _onMapTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.thews.fitnessapp',
                  tileProvider: PersistentDiskTileProvider(),
                ),
                // Glowing background polyline for drawn route
                if (_waypoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _waypoints,
                        strokeWidth: 8.0,
                        color: (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.35),
                      ),
                      Polyline(
                        points: _waypoints,
                        strokeWidth: 4.5,
                        color: isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary,
                      ),
                    ],
                  ),

                // 1. Athlete Current GPS Location Pointer (Live Pulse Marker)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: state.userLocation,
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Radar Pulse Ring
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary)
                                  .withValues(alpha: 0.20),
                            ),
                          ),
                          // Middle Pulsing Ring
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isDark
                                      ? AppColors.primaryVolt
                                      : AppColors.lightPrimary)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          // Core GPS Navigation Pointer Dot
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.near_me,
                              size: 13,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2. Start, Intermediate Waypoints, and End Loop Markers
                if (_waypoints.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      // Start Marker
                      Marker(
                        point: _waypoints.first,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.flag,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // Intermediate Waypoints
                      for (int i = 1; i < _waypoints.length - 1; i++)
                        Marker(
                          point: _waypoints[i],
                          width: 14,
                          height: 14,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primaryVolt
                                  : AppColors.lightPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      // Last Placed Marker
                      if (_waypoints.length > 1)
                        Marker(
                          point: _waypoints.last,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerHighest
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${_waypoints.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Floating Top Header: Back Button & Live Distance HUD
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _buildGlassIconButton(
                  icon: Icons.arrow_back,
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  isDark: isDark,
                  tooltip: 'Cancel',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHighest
                              .withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TAP MAP TO PLOT ROUTE',
                              style: AppTypography.tinyLabel(
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                              ).copyWith(fontSize: 8, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              softWrap: false,
                            ),
                            Text(
                              _calculatedDistanceMeters >= 1000
                                  ? '${(_calculatedDistanceMeters / 1000.0).toStringAsFixed(2)} KM'
                                  : '${_calculatedDistanceMeters.round()} METERS',
                              style: AppTypography.cardTitle(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ).copyWith(fontWeight: FontWeight.w900, fontSize: 13),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainer
                                : AppColors.lightSurfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+$xp XP',
                            style: AppTypography.labelCaps(
                              color: const Color(0xFFFFD700),
                            ).copyWith(fontWeight: FontWeight.w900, fontSize: 11),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick tip: Pointer marks current location
          if (_waypoints.isEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : Colors.white)
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark
                            ? AppColors.primaryVolt
                            : AppColors.lightPrimary)
                        .withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.near_me,
                      size: 14,
                      color: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pointer marks your current location',
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
            ),

          // Floating Route Edit Tools (Undo, Snap Loop, Clear, Zoom)
          Positioned(
            right: 16,
            bottom: 340,
            child: Column(
              children: [
                _buildGlassIconButton(
                  icon: Icons.undo,
                  onPressed: _waypoints.isEmpty ? null : _undoLastPoint,
                  isDark: isDark,
                  tooltip: 'Undo Last Point',
                ),
                const SizedBox(height: 8),
                _buildGlassIconButton(
                  icon: Icons.all_inclusive,
                  onPressed: _waypoints.length < 2 ? null : _closeLoop,
                  isDark: isDark,
                  tooltip: 'Snap Closed Loop',
                  color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                ),
                const SizedBox(height: 8),
                _buildGlassIconButton(
                  icon: Icons.refresh,
                  onPressed: _waypoints.isEmpty ? null : _clearRoute,
                  isDark: isDark,
                  tooltip: 'Clear Route',
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                _buildGlassIconButton(
                  icon: Icons.my_location,
                  onPressed: _centerOnUser,
                  isDark: isDark,
                  tooltip: 'Center on My GPS',
                ),
                const SizedBox(height: 8),
                _buildGlassIconButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                  isDark: isDark,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildGlassIconButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                  isDark: isDark,
                  tooltip: 'Zoom Out',
                ),
              ],
            ),
          ),

          // Bottom Configuration Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: AppSpacing.base,
                right: AppSpacing.base,
                top: AppSpacing.md,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHighest.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                      .withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkOutline
                                : AppColors.lightOutline)
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Challenge Title Input
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Challenge Name',
                      hintText: 'e.g. Waterfront 5K Circuit',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.lightSurfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Difficulty Selector
                  SegmentedButton<ChallengeDifficulty>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ChallengeDifficulty.easy,
                        label: Text('EASY', maxLines: 1, softWrap: false),
                      ),
                      ButtonSegment(
                        value: ChallengeDifficulty.medium,
                        label: Text('MEDIUM', maxLines: 1, softWrap: false),
                      ),
                      ButtonSegment(
                        value: ChallengeDifficulty.hard,
                        label: Text('HARD', maxLines: 1, softWrap: false),
                      ),
                    ],
                    selected: {_selectedDifficulty},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _selectedDifficulty = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Action Button (Single-line constraint adhered)
                  ElevatedButton.icon(
                    onPressed: isValid ? _saveChallenge : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isDark
                          ? AppColors.primaryVolt
                          : AppColors.lightPrimary,
                      foregroundColor: isDark
                          ? AppColors.darkBackground
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 22),
                    label: Text(
                      isValid
                          ? 'CREATE & SAVE CHALLENGE'
                          : 'PLOT ROUTE (MIN 2 POINTS)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    required String tooltip,
    Color? color,
  }) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
                .withValues(alpha: isEnabled ? 0.85 : 0.4)
            : Colors.white.withValues(alpha: isEnabled ? 0.9 : 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                .withValues(alpha: 0.3),
          ),
        ),
        elevation: isEnabled ? 4 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? (color ??
                      (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary))
                  : Colors.grey.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
