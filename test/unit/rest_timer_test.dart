import 'package:flutter_test/flutter_test.dart';
import 'package:thews/features/workouts/presentation/rest_timer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RestTimerNotifier notifier;

  setUp(() {
    notifier = RestTimerNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('RestTimerNotifier Unit Tests', () {
    test('initial state is not running and not expired', () {
      expect(notifier.state.isRunning, false);
      expect(notifier.state.isExpired, false);
      expect(notifier.state.secondsRemaining, 0);
    });

    test('startTimer initializes state correctly and starts countdown', () {
      notifier.startTimer(durationSeconds: 60);

      expect(notifier.state.isRunning, true);
      expect(notifier.state.isExpired, false);
      expect(notifier.state.secondsRemaining, 60);
      expect(notifier.state.totalDuration, 60);
      expect(notifier.state.formattedTime, '01:00');
      expect(notifier.state.progress, 1.0);
    });

    test('pauseTimer pauses the active timer without resetting remaining time', () {
      notifier.startTimer(durationSeconds: 90);
      expect(notifier.state.isRunning, true);

      notifier.pauseTimer();

      expect(notifier.state.isRunning, false);
      expect(notifier.state.secondsRemaining, 90);
      expect(notifier.state.isExpired, false);
    });

    test('resumeTimer resumes paused timer', () {
      notifier.startTimer(durationSeconds: 45);
      notifier.pauseTimer();
      expect(notifier.state.isRunning, false);

      notifier.resumeTimer();
      expect(notifier.state.isRunning, true);
      expect(notifier.state.isExpired, false);
      expect(notifier.state.secondsRemaining, 45);
    });

    test('addTime increases secondsRemaining and totalDuration', () {
      notifier.startTimer(durationSeconds: 30);
      notifier.addTime(30);

      expect(notifier.state.secondsRemaining, 60);
      expect(notifier.state.totalDuration, 60);
      expect(notifier.state.formattedTime, '01:00');
    });

    test('stopTimer cancels timer and resets state', () {
      notifier.startTimer(durationSeconds: 120);
      expect(notifier.state.isRunning, true);

      notifier.stopTimer();

      expect(notifier.state.isRunning, false);
      expect(notifier.state.isExpired, false);
      expect(notifier.state.secondsRemaining, 0);
    });

    test('resumeTimer on empty timer does nothing', () {
      notifier.resumeTimer();
      expect(notifier.state.isRunning, false);
    });
  });
}
