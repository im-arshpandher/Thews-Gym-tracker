import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/smartwatch_models.dart';

class AudioCoachConfig {
  final bool isVoiceEnabled;
  final double speechRate; // 0.3 to 0.8 (default: 0.5)
  final double pitch; // 0.8 to 1.2 (default: 1.0)
  final double volume; // 0.0 to 1.0 (default: 1.0)
  final double splitIntervalMeters; // e.g. 500, 1000, 1609.34, 2000
  final bool announceSplitPace;
  final bool announceTotalDistance;
  final bool announceElapsedTime;
  final bool announceHeartRate;
  final bool announceCurrentPace;
  final double? targetDistanceMeters; // e.g. 5000, 10000
  final bool hrZoneAlertsEnabled;
  final HeartRateZoneType? targetHrZone; // e.g. Zone 2
  final int hrAlertCooldownSeconds; // debounce duration

  const AudioCoachConfig({
    this.isVoiceEnabled = true,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.splitIntervalMeters = 1000.0,
    this.announceSplitPace = true,
    this.announceTotalDistance = true,
    this.announceElapsedTime = true,
    this.announceHeartRate = true,
    this.announceCurrentPace = true,
    this.targetDistanceMeters,
    this.hrZoneAlertsEnabled = true,
    this.targetHrZone,
    this.hrAlertCooldownSeconds = 45,
  });

  AudioCoachConfig copyWith({
    bool? isVoiceEnabled,
    double? speechRate,
    double? pitch,
    double? volume,
    double? splitIntervalMeters,
    bool? announceSplitPace,
    bool? announceTotalDistance,
    bool? announceElapsedTime,
    bool? announceHeartRate,
    bool? announceCurrentPace,
    double? targetDistanceMeters,
    bool clearTargetDistance = false,
    bool? hrZoneAlertsEnabled,
    HeartRateZoneType? targetHrZone,
    bool clearTargetHrZone = false,
    int? hrAlertCooldownSeconds,
  }) {
    return AudioCoachConfig(
      isVoiceEnabled: isVoiceEnabled ?? this.isVoiceEnabled,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      splitIntervalMeters: splitIntervalMeters ?? this.splitIntervalMeters,
      announceSplitPace: announceSplitPace ?? this.announceSplitPace,
      announceTotalDistance:
          announceTotalDistance ?? this.announceTotalDistance,
      announceElapsedTime: announceElapsedTime ?? this.announceElapsedTime,
      announceHeartRate: announceHeartRate ?? this.announceHeartRate,
      announceCurrentPace: announceCurrentPace ?? this.announceCurrentPace,
      targetDistanceMeters: clearTargetDistance
          ? null
          : (targetDistanceMeters ?? this.targetDistanceMeters),
      hrZoneAlertsEnabled: hrZoneAlertsEnabled ?? this.hrZoneAlertsEnabled,
      targetHrZone: clearTargetHrZone
          ? null
          : (targetHrZone ?? this.targetHrZone),
      hrAlertCooldownSeconds:
          hrAlertCooldownSeconds ?? this.hrAlertCooldownSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'isVoiceEnabled': isVoiceEnabled,
        'speechRate': speechRate,
        'pitch': pitch,
        'volume': volume,
        'splitIntervalMeters': splitIntervalMeters,
        'announceSplitPace': announceSplitPace,
        'announceTotalDistance': announceTotalDistance,
        'announceElapsedTime': announceElapsedTime,
        'announceHeartRate': announceHeartRate,
        'announceCurrentPace': announceCurrentPace,
        'targetDistanceMeters': targetDistanceMeters,
        'hrZoneAlertsEnabled': hrZoneAlertsEnabled,
        'targetHrZone': targetHrZone?.name,
        'hrAlertCooldownSeconds': hrAlertCooldownSeconds,
      };

  factory AudioCoachConfig.fromJson(Map<String, dynamic> json) {
    HeartRateZoneType? parsedZone;
    if (json['targetHrZone'] != null) {
      parsedZone = HeartRateZoneType.values
          .where((z) => z.name == json['targetHrZone'])
          .firstOrNull;
    }

    return AudioCoachConfig(
      isVoiceEnabled: json['isVoiceEnabled'] as bool? ?? true,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      splitIntervalMeters:
          (json['splitIntervalMeters'] as num?)?.toDouble() ?? 1000.0,
      announceSplitPace: json['announceSplitPace'] as bool? ?? true,
      announceTotalDistance: json['announceTotalDistance'] as bool? ?? true,
      announceElapsedTime: json['announceElapsedTime'] as bool? ?? true,
      announceHeartRate: json['announceHeartRate'] as bool? ?? true,
      announceCurrentPace: json['announceCurrentPace'] as bool? ?? true,
      targetDistanceMeters:
          (json['targetDistanceMeters'] as num?)?.toDouble(),
      hrZoneAlertsEnabled: json['hrZoneAlertsEnabled'] as bool? ?? true,
      targetHrZone: parsedZone,
      hrAlertCooldownSeconds:
          (json['hrAlertCooldownSeconds'] as num?)?.toInt() ?? 45,
    );
  }
}

class AudioCoachState {
  final AudioCoachConfig config;
  final bool isSpeaking;
  final String? lastAnnouncementText;
  final DateTime? lastAnnouncementTime;
  final DateTime? lastHrAlertTime;
  final HeartRateZoneType? lastAlertedZone;

  const AudioCoachState({
    this.config = const AudioCoachConfig(),
    this.isSpeaking = false,
    this.lastAnnouncementText,
    this.lastAnnouncementTime,
    this.lastHrAlertTime,
    this.lastAlertedZone,
  });

  AudioCoachState copyWith({
    AudioCoachConfig? config,
    bool? isSpeaking,
    String? lastAnnouncementText,
    bool clearLastAnnouncementText = false,
    DateTime? lastAnnouncementTime,
    bool clearLastAnnouncementTime = false,
    DateTime? lastHrAlertTime,
    bool clearLastHrAlertTime = false,
    HeartRateZoneType? lastAlertedZone,
    bool clearLastAlertedZone = false,
  }) {
    return AudioCoachState(
      config: config ?? this.config,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      lastAnnouncementText: clearLastAnnouncementText
          ? null
          : (lastAnnouncementText ?? this.lastAnnouncementText),
      lastAnnouncementTime: clearLastAnnouncementTime
          ? null
          : (lastAnnouncementTime ?? this.lastAnnouncementTime),
      lastHrAlertTime: clearLastHrAlertTime
          ? null
          : (lastHrAlertTime ?? this.lastHrAlertTime),
      lastAlertedZone: clearLastAlertedZone
          ? null
          : (lastAlertedZone ?? this.lastAlertedZone),
    );
  }
}

class AudioCoachService extends StateNotifier<AudioCoachState> {
  static const String _keyPrefs = 'thews_audio_coach_config';
  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsInitialized = false;

  AudioCoachService() : super(const AudioCoachState()) {
    _loadConfig();
    _initTts();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyPrefs);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        state = state.copyWith(config: AudioCoachConfig.fromJson(data));
      }
    } catch (e) {
      debugPrint('AudioCoach load config notice: $e');
    }
  }

  Future<void> _saveConfig(AudioCoachConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPrefs, jsonEncode(config.toJson()));
    } catch (e) {
      debugPrint('AudioCoach save config notice: $e');
    }
  }

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    try {
      await _flutterTts.setLanguage('en-US').catchError((e) {
        debugPrint('TTS setLanguage notice: $e');
        return null;
      });
      await _flutterTts.setSpeechRate(state.config.speechRate).catchError((e) {
        debugPrint('TTS setSpeechRate notice: $e');
        return null;
      });
      await _flutterTts.setVolume(state.config.volume).catchError((e) {
        debugPrint('TTS setVolume notice: $e');
        return null;
      });
      await _flutterTts.setPitch(state.config.pitch).catchError((e) {
        debugPrint('TTS setPitch notice: $e');
        return null;
      });

      _flutterTts.setStartHandler(() {
        state = state.copyWith(isSpeaking: true);
      });

      _flutterTts.setCompletionHandler(() {
        state = state.copyWith(isSpeaking: false);
      });

      _flutterTts.setErrorHandler((e) {
        debugPrint('TTS error handler notice: $e');
        state = state.copyWith(isSpeaking: false);
      });

      _ttsInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization notice: $e');
    }
  }

  Future<void> updateConfig(AudioCoachConfig newConfig) async {
    state = state.copyWith(config: newConfig);
    await _saveConfig(newConfig);
    try {
      await _flutterTts.setSpeechRate(newConfig.speechRate).catchError((e) {
        debugPrint('TTS update speech rate notice: $e');
        return null;
      });
      await _flutterTts.setVolume(newConfig.volume).catchError((e) {
        debugPrint('TTS update volume notice: $e');
        return null;
      });
      await _flutterTts.setPitch(newConfig.pitch).catchError((e) {
        debugPrint('TTS update pitch notice: $e');
        return null;
      });
    } catch (e) {
      debugPrint('TTS update config notice: $e');
    }
  }

  /// Speak plain cue text through TTS engine
  Future<void> speak(String text) async {
    if (!state.config.isVoiceEnabled || text.trim().isEmpty) return;

    state = state.copyWith(
      lastAnnouncementText: text,
      lastAnnouncementTime: DateTime.now(),
    );

    try {
      await _initTts();
      await _flutterTts.stop().catchError((e) {
        debugPrint('TTS stop notice: $e');
        return null;
      });
      await _flutterTts.speak(text).catchError((e) {
        debugPrint('TTS speak error notice: $e');
        return null;
      });
    } catch (e) {
      debugPrint('TTS speak failure notice: $e');
    }
  }

  /// Format pace into spoken voice text (e.g. "4 minutes 55 seconds per kilometer")
  static String formatPaceForSpeech(double paceSecondsPerKm) {
    if (paceSecondsPerKm <= 0 || paceSecondsPerKm.isInfinite || paceSecondsPerKm.isNaN) {
      return 'pace unavailable';
    }
    final mins = paceSecondsPerKm ~/ 60;
    final secs = (paceSecondsPerKm % 60).round();
    if (secs == 0) {
      return '$mins minutes per kilometer';
    }
    return '$mins minutes $secs seconds per kilometer';
  }

  /// Format duration into spoken voice text (e.g. "24 minutes 10 seconds")
  static String formatDurationForSpeech(int durationSeconds) {
    final hrs = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;

    if (hrs > 0) {
      if (mins == 0) return '$hrs hours $secs seconds';
      return '$hrs hours $mins minutes $secs seconds';
    }
    if (mins == 0) {
      return '$secs seconds';
    }
    return '$mins minutes $secs seconds';
  }

  /// Format distance in kilometers or meters
  static String formatDistanceForSpeech(double distanceMeters) {
    final km = distanceMeters / 1000.0;
    if (km < 1.0) {
      return '${distanceMeters.round()} meters';
    }
    final formatted = km.toStringAsFixed(km < 10.0 ? 1 : 0);
    return '$formatted kilometers';
  }

  /// Announce split trigger telemetry
  Future<void> announceSplit({
    required int splitIndex,
    required double totalDistanceMeters,
    required int totalDurationSeconds,
    required double splitPaceSecondsPerKm,
    double? currentPaceSecondsPerKm,
    int? currentHeartRateBpm,
  }) async {
    if (!state.config.isVoiceEnabled) return;

    final parts = <String>[];
    parts.add('Split $splitIndex completed.');

    if (state.config.announceTotalDistance) {
      parts.add('Total distance: ${formatDistanceForSpeech(totalDistanceMeters)}.');
    }

    if (state.config.announceElapsedTime) {
      parts.add('Total time: ${formatDurationForSpeech(totalDurationSeconds)}.');
    }

    if (state.config.announceSplitPace) {
      parts.add('Split pace: ${formatPaceForSpeech(splitPaceSecondsPerKm)}.');
    }

    if (state.config.announceCurrentPace && currentPaceSecondsPerKm != null && currentPaceSecondsPerKm > 0) {
      parts.add('Current pace: ${formatPaceForSpeech(currentPaceSecondsPerKm)}.');
    }

    if (state.config.announceHeartRate && currentHeartRateBpm != null && currentHeartRateBpm > 0) {
      parts.add('Heart rate: $currentHeartRateBpm beats per minute.');
    }

    if (state.config.targetDistanceMeters != null &&
        state.config.targetDistanceMeters! > totalDistanceMeters) {
      final remaining =
          state.config.targetDistanceMeters! - totalDistanceMeters;
      parts.add(
          'Target: ${formatDistanceForSpeech(remaining)} remaining.');
    } else if (state.config.targetDistanceMeters != null &&
        totalDistanceMeters >= state.config.targetDistanceMeters!) {
      parts.add('Target race distance achieved! Awesome work.');
    }

    final announcement = parts.join(' ');
    await speak(announcement);
  }

  /// Evaluates heart rate relative to user's target HR zone and triggers boundary voice alerts
  Future<void> evaluateHeartRateZone({
    required int currentBpm,
    required HeartRateZone currentZone,
  }) async {
    if (!state.config.isVoiceEnabled ||
        !state.config.hrZoneAlertsEnabled ||
        state.config.targetHrZone == null ||
        currentBpm <= 0) {
      return;
    }

    final targetZoneType = state.config.targetHrZone!;
    final now = DateTime.now();

    // Check cooldown
    if (state.lastHrAlertTime != null) {
      final elapsedSecs =
          now.difference(state.lastHrAlertTime!).inSeconds;
      if (elapsedSecs < state.config.hrAlertCooldownSeconds) {
        return;
      }
    }

    final targetZones = HeartRateZone.calculateZones();
    final targetZone = targetZones.firstWhere(
      (z) => z.type == targetZoneType,
      orElse: () => targetZones[1], // default Zone 2
    );

    // Drifting higher than target zone
    if (currentBpm > targetZone.maxBpm) {
      if (state.lastAlertedZone != currentZone.type) {
        final alertText =
            'Warning: Exiting ${targetZone.name}. Current heart rate is $currentBpm beats per minute. Ease your pace.';
        state = state.copyWith(
          lastHrAlertTime: now,
          lastAlertedZone: currentZone.type,
        );
        await speak(alertText);
      }
    }
    // Drifting lower than target zone (only if current effort is below target minBpm)
    else if (currentBpm < targetZone.minBpm) {
      if (state.lastAlertedZone != currentZone.type) {
        final alertText =
            'Heart rate dropped to $currentBpm beats per minute, below ${targetZone.name}. Pick up your pace.';
        state = state.copyWith(
          lastHrAlertTime: now,
          lastAlertedZone: currentZone.type,
        );
        await speak(alertText);
      }
    }
    // Returned back into target zone
    else if (state.lastAlertedZone != null &&
        state.lastAlertedZone != targetZoneType) {
      final alertText = 'Great job. Heart rate is back in target ${targetZone.name}.';
      state = state.copyWith(
        lastHrAlertTime: now,
        lastAlertedZone: targetZoneType,
      );
      await speak(alertText);
    }
  }

  /// Voice prompts for workout milestones or activity status changes
  Future<void> announceActivityEvent(String message) async {
    await speak(message);
  }

  @override
  void dispose() {
    try {
      _flutterTts.stop().catchError((e) {
        debugPrint('TTS stop on dispose notice: $e');
        return null;
      });
    } catch (e) {
      debugPrint('TTS dispose notice: $e');
    }
    super.dispose();
  }
}

final audioCoachServiceProvider =
    StateNotifierProvider<AudioCoachService, AudioCoachState>((ref) {
  return AudioCoachService();
});
