import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/utils/volume_calculator.dart';

void main() {
  group('VolumeCalculator Tests', () {
    test('Calculates standard set volume in kg', () {
      final vol = VolumeCalculator.calculateSetVolume(
        weight: 100.0,
        reps: 10,
        type: 'normal',
        unit: 'kg',
      );
      expect(vol, 1000.0);
    });

    test('Excludes warmup set volume', () {
      final vol = VolumeCalculator.calculateSetVolume(
        weight: 100.0,
        reps: 10,
        type: 'warmup',
        unit: 'kg',
      );
      expect(vol, 0.0);
    });

    test('Converts lbs weight to kg volume correctly', () {
      final vol = VolumeCalculator.calculateSetVolume(
        weight: 100.0,
        reps: 10,
        type: 'normal',
        unit: 'lbs',
      );
      expect((vol).toStringAsFixed(2), '453.59');
    });
  });
}
