import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/challenge_models.dart';
import 'challenges_provider.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(challengesProvider.notifier).syncWithUserLocation();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(challengesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LOCALITY CHALLENGES',
          style: AppTypography.headlineMd(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          maxLines: 1,
          softWrap: false,
        ),
        actions: [
          IconButton(
            tooltip: 'Create Custom Challenge',
            icon: Icon(
              Icons.add_circle_outline,
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
              size: 24,
            ),
            onPressed: () => context.push('/challenges/create'),
          ),
          IconButton(
            tooltip: 'Athlete Trophy Room',
            icon: const Icon(Icons.emoji_events, color: Colors.amber),
            onPressed: () => context.push('/profile'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor:
              isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
          labelColor:
              isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
          unselectedLabelColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          labelStyle: AppTypography.labelCaps().copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'EASY'),
            Tab(text: 'MEDIUM'),
            Tab(text: 'HARD'),
          ],
        ),
      ),
      body: Column(
        children: [
          // GPS Locality & Road Snapping Control Bar
          _buildGpsLocalityBar(context, state, isDark),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChallengeList(state.challenges, isDark),
                _buildChallengeList(
                  state.challenges
                      .where((c) => c.difficulty == ChallengeDifficulty.easy)
                      .toList(),
                  isDark,
                ),
                _buildChallengeList(
                  state.challenges
                      .where((c) => c.difficulty == ChallengeDifficulty.medium)
                      .toList(),
                  isDark,
                ),
                _buildChallengeList(
                  state.challenges
                      .where((c) => c.difficulty == ChallengeDifficulty.hard)
                      .toList(),
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsLocalityBar(
    BuildContext context,
    ChallengesState state,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                .withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.my_location,
              size: 16,
              color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'TODAY\'S NEIGHBORHOOD CIRCUITS',
                        style: AppTypography.labelCaps(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ).copyWith(fontSize: 9, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.primaryVolt : AppColors.lightPrimary)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DAILY ROTATION',
                        style: AppTypography.labelCaps(
                          color: isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
                        ).copyWith(fontSize: 8, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    if (state.isRoadSnapped) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'REAL STREETS',
                          style: AppTypography.labelCaps(
                            color: AppColors.success,
                          ).copyWith(fontSize: 8, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${state.userLocation.latitude.toStringAsFixed(4)}, ${state.userLocation.longitude.toStringAsFixed(4)}',
                  style: AppTypography.cardTitle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ).copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => context.push('/challenges/create'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.primaryVolt : AppColors.lightPrimary,
              foregroundColor: AppColors.primaryVoltOn,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 14),
            label: const Text(
              'NEW ROUTE',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Snap to GPS Location',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(challengesProvider.notifier)
                    .syncWithUserLocation(),
            icon: state.isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeList(List<LocalChallenge> challenges, bool isDark) {
    if (challenges.isEmpty) {
      return Center(
        child: Text(
          'No challenges available in this tier.',
          style: AppTypography.bodyMd(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: challenges.length,
      separatorBuilder: (context, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        return FadeSlideEntrance(
          delay: Duration(milliseconds: (index * 50).clamp(0, 400)),
          child: BouncingButton(
            onTap: () {
              context.push(
                '/challenges/detail/${challenges[index].id}',
                extra: challenges[index],
              );
            },
            child: _buildChallengeCard(context, challenges[index], isDark),
          ),
        );
      },
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    LocalChallenge challenge,
    bool isDark,
  ) {
    final tierColor = _getDifficultyColor(challenge.difficulty);
    final trophyTierColor = _getTrophyTierColor(challenge.trophyReward.tier);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          context.push('/challenges/detail/${challenge.id}', extra: challenge);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerLow
                : AppColors.lightSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: challenge.isCompleted
                  ? AppColors.primaryVolt.withValues(alpha: 0.6)
                  : (isDark ? AppColors.darkOutline : AppColors.lightOutline)
                      .withValues(alpha: 0.3),
              width: challenge.isCompleted ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header: Difficulty Pill & Distance
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tierColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, size: 14, color: tierColor),
                      const SizedBox(width: 4),
                      Text(
                        '${challenge.difficulty.label} • ${challenge.targetDistanceKm.toStringAsFixed(1)} KM STREET LOOP',
                        style: AppTypography.labelCaps(color: tierColor)
                            .copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
                if (challenge.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryVolt.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryVolt),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.primaryVolt,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMPLETED',
                          style: AppTypography.labelCaps(
                            color: AppColors.primaryVolt,
                          ).copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: AppTypography.headlineMd(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.description,
                  style: AppTypography.bodySm(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Mini Map Loop Preview
          if (challenge.loopWaypoints.isNotEmpty)
            Container(
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark
                          ? AppColors.darkOutline
                          : AppColors.lightOutline)
                      .withValues(alpha: 0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AbsorbPointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _calculateCentroid(
                        challenge.loopWaypoints,
                      ),
                      initialZoom: _calculateZoomLevel(
                        challenge.targetDistanceMeters,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
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
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: challenge.loopWaypoints,
                            strokeWidth: 4.0,
                            color: isDark
                                ? AppColors.primaryVolt
                                : AppColors.lightPrimary,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: challenge.loopWaypoints.first,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.primaryVolt
                                    : AppColors.lightPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.flag,
                                size: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Trophy Reward Showcase & Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Trophy badge preview (Expanded to prevent overflow)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: trophyTierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: trophyTierColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 20, color: trophyTierColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.trophyReward.title,
                                style: AppTypography.labelCaps(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '+${challenge.trophyReward.xpReward} XP REWARD',
                                style: AppTypography.labelCaps(
                                  color: trophyTierColor,
                                ).copyWith(fontWeight: FontWeight.w900, fontSize: 9),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // View Map / Start loop challenge button
                ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/challenges/detail/${challenge.id}',
                      extra: challenge,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.primaryVolt
                        : AppColors.lightPrimary,
                    foregroundColor: AppColors.primaryVoltOn,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'VIEW MAP',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double latSum = 0;
    double lngSum = 0;
    for (final p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  double _calculateZoomLevel(double distanceMeters) {
    if (distanceMeters <= 3500) return 14.5;
    if (distanceMeters <= 6000) return 13.5;
    return 12.5;
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return const Color(0xFF00E676);
      case ChallengeDifficulty.medium:
        return const Color(0xFFFFB300);
      case ChallengeDifficulty.hard:
        return const Color(0xFFFF3D00);
    }
  }

  Color _getTrophyTierColor(TrophyTier tier) {
    switch (tier) {
      case TrophyTier.bronze:
        return const Color(0xFFCD7F32);
      case TrophyTier.silver:
        return const Color(0xFFCBD5E1);
      case TrophyTier.gold:
        return const Color(0xFFFFD700);
      case TrophyTier.diamond:
        return const Color(0xFF38BDF8);
    }
  }
}
