import 'package:latlong2/latlong.dart';

enum ChallengeDifficulty {
  easy,
  medium,
  hard;

  String get label {
    switch (this) {
      case ChallengeDifficulty.easy:
        return 'EASY';
      case ChallengeDifficulty.medium:
        return 'MEDIUM';
      case ChallengeDifficulty.hard:
        return 'HARD';
    }
  }
}

enum TrophyTier {
  bronze,
  silver,
  gold,
  diamond;

  String get label {
    switch (this) {
      case TrophyTier.bronze:
        return 'BRONZE';
      case TrophyTier.silver:
        return 'SILVER';
      case TrophyTier.gold:
        return 'GOLD';
      case TrophyTier.diamond:
        return 'DIAMOND';
    }
  }
}

class TrophyBadge {
  final String id;
  final String title;
  final String description;
  final TrophyTier tier;
  final String iconName;
  final String category; // 'easy', 'medium', 'hard', 'special', 'milestone'
  final int xpReward;
  final DateTime? unlockedAt;

  const TrophyBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.iconName,
    required this.category,
    required this.xpReward,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  TrophyBadge copyWith({
    String? id,
    String? title,
    String? description,
    TrophyTier? tier,
    String? iconName,
    String? category,
    int? xpReward,
    DateTime? unlockedAt,
  }) {
    return TrophyBadge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tier: tier ?? this.tier,
      iconName: iconName ?? this.iconName,
      category: category ?? this.category,
      xpReward: xpReward ?? this.xpReward,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tier': tier.name,
      'iconName': iconName,
      'category': category,
      'xpReward': xpReward,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory TrophyBadge.fromJson(Map<String, dynamic> json) {
    return TrophyBadge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      tier: TrophyTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => TrophyTier.bronze,
      ),
      iconName: json['iconName'] as String? ?? 'trophy',
      category: json['category'] as String? ?? 'milestone',
      xpReward: json['xpReward'] as int? ?? 100,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
    );
  }
}

class LocalChallenge {
  final String id;
  final String title;
  final String description;
  final ChallengeDifficulty difficulty;
  final double targetDistanceMeters;
  final int? targetDurationMinutes;
  final TrophyBadge trophyReward;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<LatLng> loopWaypoints;
  final String localityName;
  final String? dateKey;
  final bool isDaily;

  const LocalChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.targetDistanceMeters,
    this.targetDurationMinutes,
    required this.trophyReward,
    this.isCompleted = false,
    this.completedAt,
    required this.loopWaypoints,
    required this.localityName,
    this.dateKey,
    this.isDaily = true,
  });

  double get targetDistanceKm => targetDistanceMeters / 1000.0;

  LocalChallenge copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeDifficulty? difficulty,
    double? targetDistanceMeters,
    int? targetDurationMinutes,
    TrophyBadge? trophyReward,
    bool? isCompleted,
    DateTime? completedAt,
    List<LatLng>? loopWaypoints,
    String? localityName,
    String? dateKey,
    bool? isDaily,
  }) {
    return LocalChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      targetDistanceMeters:
          targetDistanceMeters ?? this.targetDistanceMeters,
      targetDurationMinutes:
          targetDurationMinutes ?? this.targetDurationMinutes,
      trophyReward: trophyReward ?? this.trophyReward,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      loopWaypoints: loopWaypoints ?? this.loopWaypoints,
      localityName: localityName ?? this.localityName,
      dateKey: dateKey ?? this.dateKey,
      isDaily: isDaily ?? this.isDaily,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty.name,
      'targetDistanceMeters': targetDistanceMeters,
      'targetDurationMinutes': targetDurationMinutes,
      'trophyReward': trophyReward.toJson(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'loopWaypoints': loopWaypoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      'localityName': localityName,
      'dateKey': dateKey,
      'isDaily': isDaily,
    };
  }

  factory LocalChallenge.fromJson(Map<String, dynamic> json) {
    final waypointsList = json['loopWaypoints'] as List<dynamic>? ?? [];
    final waypoints = waypointsList.map((p) {
      final map = p as Map<String, dynamic>;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    }).toList();

    return LocalChallenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: ChallengeDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => ChallengeDifficulty.easy,
      ),
      targetDistanceMeters: (json['targetDistanceMeters'] as num).toDouble(),
      targetDurationMinutes: json['targetDurationMinutes'] as int?,
      trophyReward: TrophyBadge.fromJson(
        json['trophyReward'] as Map<String, dynamic>,
      ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      loopWaypoints: waypoints,
      localityName: json['localityName'] as String? ?? 'Local Area',
      dateKey: json['dateKey'] as String?,
      isDaily: json['isDaily'] as bool? ?? true,
    );
  }
}
