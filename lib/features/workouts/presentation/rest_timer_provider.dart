import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RestTimerState {
  final int secondsRemaining;
  final int totalDuration;
  final bool isRunning;
  final bool isExpired;

  const RestTimerState({
    this.secondsRemaining = 0,
    this.totalDuration = 90,
    this.isRunning = false,
    this.isExpired = false,
  });

  RestTimerState copyWith({
    int? secondsRemaining,
    int? totalDuration,
    bool? isRunning,
    bool? isExpired,
  }) {
    return RestTimerState(
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      totalDuration: totalDuration ?? this.totalDuration,
      isRunning: isRunning ?? this.isRunning,
      isExpired: isExpired ?? this.isExpired,
    );
  }

  String get formattedTime {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get progress {
    if (totalDuration <= 0) return 0.0;
    return (secondsRemaining / totalDuration).clamp(0.0, 1.0);
  }
}

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  Timer? _timer;

  RestTimerNotifier() : super(const RestTimerState());

  void startTimer({int durationSeconds = 90}) {
    _timer?.cancel();
    state = RestTimerState(
      secondsRemaining: durationSeconds,
      totalDuration: durationSeconds,
      isRunning: true,
      isExpired: false,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining <= 1) {
        timer.cancel();
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
        state = state.copyWith(
          secondsRemaining: 0,
          isRunning: false,
          isExpired: true,
        );
      } else {
        state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
      }
    });
  }

  void addTime(int seconds) {
    final newTime = state.secondsRemaining + seconds;
    final newTotal = state.totalDuration + seconds;
    state = state.copyWith(
      secondsRemaining: newTime,
      totalDuration: newTotal,
      isExpired: false,
    );

    if (!state.isRunning && newTime > 0) {
      resumeTimer();
    }
  }

  void pauseTimer() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resumeTimer() {
    if (state.secondsRemaining <= 0) return;
    _timer?.cancel();
    state = state.copyWith(isRunning: true, isExpired: false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining <= 1) {
        timer.cancel();
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
        state = state.copyWith(
          secondsRemaining: 0,
          isRunning: false,
          isExpired: true,
        );
      } else {
        state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    state = const RestTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final restTimerProvider =
    StateNotifierProvider<RestTimerNotifier, RestTimerState>((ref) {
      return RestTimerNotifier();
    });
