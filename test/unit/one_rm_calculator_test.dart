import 'package:flutter_test/flutter_test.dart';

double calculateEstimated1RM(double weight, int reps) {
  if (reps <= 0 || weight <= 0) return 0.0;
  if (reps == 1) return weight;
  // Epley Formula: 1RM = weight * (1 + reps / 30)
  return weight * (1 + reps / 30.0);
}

void main() {
  group('Epley 1RM Calculation Tests', () {
    test('1 Rep Max at 100kg for 1 rep returns 100kg', () {
      final e1rm = calculateEstimated1RM(100.0, 1);
      expect(e1rm, 100.0);
    });

    test('1 Rep Max at 100kg for 10 reps returns 133.33kg', () {
      final e1rm = calculateEstimated1RM(100.0, 10);
      expect(e1rm.toStringAsFixed(2), '133.33');
    });

    test('0 weight or 0 reps returns 0.0', () {
      expect(calculateEstimated1RM(0, 10), 0.0);
      expect(calculateEstimated1RM(100, 0), 0.0);
    });
  });
}
