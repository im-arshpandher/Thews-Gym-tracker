import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MetronomeFeedbackMode {
  audioOnly,
  hapticOnly,
  audioAndHaptic,
}

enum MetronomeSubdivision {
  everyStep, // 1:1 Every foot strike
  everySecondStep, // 1:2 Stride (every left or right foot)
  everyFourthStep, // 1:4 Accent cycle
}

class CadenceMetronomeState {
  final bool isPlaying;
  final int targetBpm; // 120 - 220 SPM (Steps Per Minute)
  final MetronomeFeedbackMode feedbackMode;
  final MetronomeSubdivision subdivision;
  final double volume; // 0.0 to 1.0
  final int currentTickIndex;

  const CadenceMetronomeState({
    this.isPlaying = false,
    this.targetBpm = 175,
    this.feedbackMode = MetronomeFeedbackMode.audioAndHaptic,
    this.subdivision = MetronomeSubdivision.everyStep,
    this.volume = 1.0,
    this.currentTickIndex = 0,
  });

  CadenceMetronomeState copyWith({
    bool? isPlaying,
    int? targetBpm,
    MetronomeFeedbackMode? feedbackMode,
    MetronomeSubdivision? subdivision,
    double? volume,
    int? currentTickIndex,
  }) {
    return CadenceMetronomeState(
      isPlaying: isPlaying ?? this.isPlaying,
      targetBpm: targetBpm ?? this.targetBpm,
      feedbackMode: feedbackMode ?? this.feedbackMode,
      subdivision: subdivision ?? this.subdivision,
      volume: volume ?? this.volume,
      currentTickIndex: currentTickIndex ?? this.currentTickIndex,
    );
  }
}

class CadenceMetronomeService extends StateNotifier<CadenceMetronomeState> {
  static const String _keyBpm = 'thews_cadence_metronome_bpm';
  static const String _keyMode = 'thews_cadence_metronome_mode';
  static const String _keySubdiv = 'thews_cadence_metronome_subdiv';
  static const String _keyVolume = 'thews_cadence_metronome_volume';

  Timer? _tickerTimer;
  int _tickCount = 0;
  final AudioPlayer _player = AudioPlayer(playerId: 'cadence_metronome');
  bool _audioInitialized = false;
  bool _isPreferencesLoaded = false;

  CadenceMetronomeService() : super(const CadenceMetronomeState()) {
    _loadPreferences();
    _initAudio();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isPreferencesLoaded || !mounted) return;
      final bpm = prefs.getInt(_keyBpm) ?? 175;
      final modeIndex = prefs.getInt(_keyMode);
      final subdivIndex = prefs.getInt(_keySubdiv);
      final volume = prefs.getDouble(_keyVolume) ?? 1.0;

      final mode = modeIndex != null &&
              modeIndex >= 0 &&
              modeIndex < MetronomeFeedbackMode.values.length
          ? MetronomeFeedbackMode.values[modeIndex]
          : MetronomeFeedbackMode.audioAndHaptic;

      final subdiv = subdivIndex != null &&
              subdivIndex >= 0 &&
              subdivIndex < MetronomeSubdivision.values.length
          ? MetronomeSubdivision.values[subdivIndex]
          : MetronomeSubdivision.everyStep;

      if (!mounted) return;
      state = state.copyWith(
        targetBpm: bpm.clamp(120, 220),
        feedbackMode: mode,
        subdivision: subdiv,
        volume: volume.clamp(0.0, 1.0),
      );
      _isPreferencesLoaded = true;
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      _isPreferencesLoaded = true;
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyBpm, state.targetBpm);
      await prefs.setInt(_keyMode, state.feedbackMode.index);
      await prefs.setInt(_keySubdiv, state.subdivision.index);
      await prefs.setDouble(_keyVolume, state.volume);
    } catch (_) {}
  }

  void setBpm(int bpm) {
    final clamped = bpm.clamp(120, 220);
    state = state.copyWith(targetBpm: clamped);
    _savePreferences();
    if (state.isPlaying) {
      _restartTimer();
    }
  }

  void setFeedbackMode(MetronomeFeedbackMode mode) {
    state = state.copyWith(feedbackMode: mode);
    _savePreferences();
  }

  void setSubdivision(MetronomeSubdivision subdiv) {
    state = state.copyWith(subdivision: subdiv);
    _savePreferences();
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    _savePreferences();
    try {
      _player.setVolume(clamped);
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    if (_audioInitialized) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(state.volume);
      _audioInitialized = true;
    } catch (_) {
      _audioInitialized = true;
    }
  }

  void start() {
    if (state.isPlaying) return;
    state = state.copyWith(isPlaying: true, currentTickIndex: 0);
    _tickCount = 0;
    _initAudio();
    _startTimer();
  }

  void stop() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    try {
      _player.stop();
    } catch (_) {}
    state = state.copyWith(isPlaying: false);
  }

  void toggle() {
    if (state.isPlaying) {
      stop();
    } else {
      start();
    }
  }

  void _startTimer() {
    _tickerTimer?.cancel();
    final microseconds = (60000000 / state.targetBpm).round();
    _tickerTimer = Timer.periodic(
      Duration(microseconds: microseconds),
      (_) => _handleTick(),
    );
    _handleTick();
  }

  void _restartTimer() {
    if (state.isPlaying) {
      _tickerTimer?.cancel();
      _startTimer();
    }
  }

  void _handleTick() {
    _tickCount++;
    final tickIdx = _tickCount % 4;
    state = state.copyWith(currentTickIndex: tickIdx);

    bool shouldTrigger = false;
    switch (state.subdivision) {
      case MetronomeSubdivision.everyStep:
        shouldTrigger = true;
        break;
      case MetronomeSubdivision.everySecondStep:
        shouldTrigger = (_tickCount % 2 == 0);
        break;
      case MetronomeSubdivision.everyFourthStep:
        shouldTrigger = (_tickCount % 4 == 0);
        break;
    }

    if (!shouldTrigger) return;

    final isAccent = (_tickCount % 4 == 1);

    if (state.feedbackMode == MetronomeFeedbackMode.audioOnly ||
        state.feedbackMode == MetronomeFeedbackMode.audioAndHaptic) {
      _playAudioClick(isAccent);
    }

    if (state.feedbackMode == MetronomeFeedbackMode.hapticOnly ||
        state.feedbackMode == MetronomeFeedbackMode.audioAndHaptic) {
      _triggerHapticPulse(isAccent);
    }
  }

  void _playAudioClick(bool isAccent) {
    final vol = state.volume.clamp(0.0, 1.0);
    if (vol <= 0.0) return;

    try {
      final soundAsset = isAccent
          ? 'sounds/metronome_accent.wav'
          : 'sounds/metronome_click.wav';
      _player.play(AssetSource(soundAsset), volume: vol).catchError((_) {
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      });
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  void _triggerHapticPulse(bool isAccent) {
    try {
      if (isAccent) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}

    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    try {
      _player.dispose();
    } catch (_) {}
    super.dispose();
  }
}

final cadenceMetronomeProvider =
    StateNotifierProvider<CadenceMetronomeService, CadenceMetronomeState>(
        (ref) {
  return CadenceMetronomeService();
});
