import 'dart:async';
import 'dart:math' as math;
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
  static const int _poolSize = 4;
  final List<AudioPlayer> _playerPool = List.generate(
    _poolSize,
    (i) => AudioPlayer(playerId: 'cadence_metronome_$i'),
  );
  int _poolIndex = 0;
  bool _audioInitialized = false;
  bool _isPreferencesLoaded = false;
  Uint8List? _clickBytes;
  Uint8List? _accentBytes;

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
    for (final player in _playerPool) {
      try {
        player.setVolume(clamped);
      } catch (_) {}
    }
  }

  Future<void> _initAudio() async {
    if (_audioInitialized) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
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

      for (final player in _playerPool) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(state.volume);
      }

      // Preload WAV sound buffers from asset bundle or generate synthetic fallbacks
      try {
        final clickData = await rootBundle.load('assets/sounds/metronome_click.wav');
        _clickBytes = clickData.buffer.asUint8List();
      } catch (_) {
        _clickBytes = _generateWavBytes(freq: 1200.0, durationMs: 25);
      }

      try {
        final accentData = await rootBundle.load('assets/sounds/metronome_accent.wav');
        _accentBytes = accentData.buffer.asUint8List();
      } catch (_) {
        _accentBytes = _generateWavBytes(freq: 2000.0, durationMs: 30);
      }

      _audioInitialized = true;
    } catch (_) {
      _clickBytes ??= _generateWavBytes(freq: 1200.0, durationMs: 25);
      _accentBytes ??= _generateWavBytes(freq: 2000.0, durationMs: 30);
      _audioInitialized = true;
    }
  }

  static Uint8List _generateWavBytes({required double freq, required int durationMs}) {
    const sampleRate = 44100;
    final totalSamples = (sampleRate * (durationMs / 1000.0)).round();
    final dataSize = totalSamples * 2; // 16-bit mono = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
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
    buffer.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    buffer.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    buffer.setUint32(24, sampleRate, Endian.little); // SampleRate
    buffer.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little);  // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample (16-bit)

    // data subchunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final decay = math.exp(-120.0 * t);
      final sampleVal = (math.sin(2.0 * math.pi * freq * t) * decay * 32767.0).clamp(-32768.0, 32767.0).toInt();
      buffer.setInt16(44 + (i * 2), sampleVal, Endian.little);
    }

    return buffer.buffer.asUint8List();
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
    for (final player in _playerPool) {
      try {
        player.stop();
      } catch (_) {}
    }
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

    final bytes = isAccent ? _accentBytes : _clickBytes;
    final soundAsset = isAccent
        ? 'sounds/metronome_accent.wav'
        : 'sounds/metronome_click.wav';

    try {
      final player = _playerPool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize;

      if (bytes != null && bytes.isNotEmpty) {
        player.play(BytesSource(bytes), volume: vol).catchError((_) {
          try {
            player.play(AssetSource(soundAsset), volume: vol).catchError((_) {
              try {
                SystemSound.play(SystemSoundType.click);
              } catch (_) {}
            });
          } catch (_) {}
        });
      } else {
        player.play(AssetSource(soundAsset), volume: vol).catchError((_) {
          try {
            SystemSound.play(SystemSoundType.click);
          } catch (_) {}
        });
      }
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
    for (final player in _playerPool) {
      try {
        player.dispose();
      } catch (_) {}
    }
    super.dispose();
  }
}

final cadenceMetronomeProvider =
    StateNotifierProvider<CadenceMetronomeService, CadenceMetronomeState>(
        (ref) {
  return CadenceMetronomeService();
});
