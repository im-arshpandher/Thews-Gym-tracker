import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
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
    this.volume = 0.8,
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

  static Uint8List? _cachedClickBytes;
  static Uint8List? _cachedAccentBytes;

  Timer? _tickerTimer;
  int _tickCount = 0;
  AudioPlayer? _clickPlayer;
  AudioPlayer? _accentPlayer;
  bool _audioPlayersInitialized = false;

  bool _isPreferencesLoaded = false;

  CadenceMetronomeService() : super(const CadenceMetronomeState()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isPreferencesLoaded) return;
      final bpm = prefs.getInt(_keyBpm) ?? 175;
      final modeIndex = prefs.getInt(_keyMode);
      final subdivIndex = prefs.getInt(_keySubdiv);
      final volume = prefs.getDouble(_keyVolume) ?? 0.8;

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
      _clickPlayer?.setVolume(clamped);
      _accentPlayer?.setVolume(clamped);
    } catch (_) {}
  }

  static Uint8List _generateWavBytes({
    required double frequency,
    required int durationMs,
    required int sampleRate,
    required double decayRate,
  }) {
    final numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final subChunk2Size = numSamples * 2; // 16-bit mono
    final chunkSize = 36 + subChunk2Size;

    final buffer = ByteData(44 + subChunk2Size);

    // RIFF Header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, chunkSize, Endian.little);
    buffer.setUint8(8, 0x57);  // W
    buffer.setUint8(9, 0x41);  // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt subchunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    buffer.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);  // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, subChunk2Size, Endian.little);

    const maxAmplitude = 30000.0;
    final attackSamples = (sampleRate * 0.0015).round();

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate.toDouble();
      double envelope = 1.0;
      if (i < attackSamples) {
        envelope = i / attackSamples.toDouble();
      } else {
        envelope = exp(-(t - (attackSamples / sampleRate)) / decayRate);
      }

      final sampleValue = (sin(2 * pi * frequency * t) * maxAmplitude * envelope).clamp(-32768.0, 32767.0).round();
      buffer.setInt16(44 + (i * 2), sampleValue, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  Uint8List get _clickBytes {
    return _cachedClickBytes ??= _generateWavBytes(
      frequency: 1050.0,
      durationMs: 35,
      sampleRate: 44100,
      decayRate: 0.006,
    );
  }

  Uint8List get _accentBytes {
    return _cachedAccentBytes ??= _generateWavBytes(
      frequency: 1750.0,
      durationMs: 45,
      sampleRate: 44100,
      decayRate: 0.009,
    );
  }

  bool _audioPlayerDisabledDueToError = false;

  Future<void> _initAudioPlayers() async {
    if (_audioPlayersInitialized || _audioPlayerDisabledDueToError) return;
    try {
      _clickPlayer = AudioPlayer(playerId: 'metronome_click');
      _accentPlayer = AudioPlayer(playerId: 'metronome_accent');

      final audioContext = AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      );

      await _clickPlayer?.setAudioContext(audioContext);
      await _accentPlayer?.setAudioContext(audioContext);

      await _clickPlayer?.setPlayerMode(PlayerMode.lowLatency);
      await _accentPlayer?.setPlayerMode(PlayerMode.lowLatency);

      await _clickPlayer?.setReleaseMode(ReleaseMode.stop);
      await _accentPlayer?.setReleaseMode(ReleaseMode.stop);

      _audioPlayersInitialized = true;
    } catch (e) {
      _audioPlayerDisabledDueToError = true;
      _clickPlayer = null;
      _accentPlayer = null;
    }
  }

  void start() {
    if (state.isPlaying) return;
    state = state.copyWith(isPlaying: true, currentTickIndex: 0);
    _tickCount = 0;
    _startTimer();
  }

  void stop() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    try {
      _clickPlayer?.stop();
      _accentPlayer?.stop();
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
    // Compute exact microsecond interval per step: (60 * 1,000,000) / targetBpm
    final microseconds = (60000000 / state.targetBpm).round();
    _tickerTimer = Timer.periodic(
      Duration(microseconds: microseconds),
      (_) => _handleTick(),
    );
    // Fire initial tick immediately
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

    // Evaluate subdivision
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

    // 1. Audio Click Playback (Pre-cached AssetSource for hardware SoundPool)
    if (state.feedbackMode == MetronomeFeedbackMode.audioOnly ||
        state.feedbackMode == MetronomeFeedbackMode.audioAndHaptic) {
      _playAudioClick(isAccent);
    }

    // 2. High-Impact Physical Tactile Vibration
    if (state.feedbackMode == MetronomeFeedbackMode.hapticOnly ||
        state.feedbackMode == MetronomeFeedbackMode.audioAndHaptic) {
      _triggerHapticPulse(isAccent);
    }
  }

  void _playAudioClick(bool isAccent) {
    if (!_audioPlayersInitialized) {
      _initAudioPlayers();
    }
    try {
      final vol = state.volume.clamp(0.0, 1.0);
      if (isAccent && _accentPlayer != null) {
        _accentPlayer!
            .play(
              AssetSource('sounds/metronome_accent.wav'),
              volume: vol,
              mode: PlayerMode.lowLatency,
            )
            .catchError((_) {
              // Fallback to memory bytes if asset lookup fails
              try {
                _accentPlayer?.play(BytesSource(_accentBytes), volume: vol);
              } catch (_) {}
            });
      } else if (_clickPlayer != null) {
        _clickPlayer!
            .play(
              AssetSource('sounds/metronome_click.wav'),
              volume: vol,
              mode: PlayerMode.lowLatency,
            )
            .catchError((_) {
              // Fallback to memory bytes if asset lookup fails
              try {
                _clickPlayer?.play(BytesSource(_clickBytes), volume: vol);
              } catch (_) {}
            });
      }
    } catch (_) {}

    // OS Audio click fallback
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void _triggerHapticPulse(bool isAccent) {
    try {
      if (isAccent) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}

    // Direct hardware vibrator pulse ensures tactile feedback across all Android OS versions
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    try {
      _clickPlayer?.dispose();
      _accentPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }
}

final cadenceMetronomeProvider =
    StateNotifierProvider<CadenceMetronomeService, CadenceMetronomeState>(
        (ref) {
  return CadenceMetronomeService();
});
