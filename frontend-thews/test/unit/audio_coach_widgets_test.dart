import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/features/running/presentation/widgets/audio_coach_settings_sheet.dart';
import 'package:thews/features/running/presentation/widgets/cadence_metronome_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  group('CadenceMetronomeSheet Widget Tests', () {
    testWidgets('Renders metronome sheet with SPM dial, chips and toggle button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CadenceMetronomeSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('CADENCE METRONOME'), findsOneWidget);
      expect(find.text('SPM (STEPS / MIN)'), findsOneWidget);
      expect(find.text('175'), findsOneWidget); // default SPM
      expect(find.text('180 SPM'), findsOneWidget);
      expect(find.text('START METRONOME'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('HAPTIC'), findsOneWidget);
      expect(find.text('BOTH'), findsOneWidget);

      // Tap preset chip 165 SPM
      await tester.tap(find.text('165 SPM'));
      await tester.pumpAndSettle();

      expect(find.text('165'), findsOneWidget);

      // Tap start metronome button
      await tester.tap(find.text('START METRONOME'));
      await tester.pump();

      expect(find.text('STOP METRONOME'), findsOneWidget);

      // Tap stop metronome button
      await tester.tap(find.text('STOP METRONOME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('START METRONOME'), findsOneWidget);
    });
  });

  group('AudioCoachSettingsSheet Widget Tests', () {
    testWidgets('Renders audio coach settings with voice switch and test button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => AudioCoachSettingsSheet.show(context),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('AUDIO COACH & SPLITS'), findsOneWidget);
      expect(find.text('Voice Coach Audio'), findsOneWidget);
      expect(find.text('HEART RATE ZONE AUDIO COACH'), findsOneWidget);
      expect(find.text('SPLIT ANNOUNCEMENT INTERVAL'), findsOneWidget);
      expect(find.text('1 km'), findsOneWidget);
      expect(find.text('Split Pace'), findsOneWidget);
      expect(find.text('Total Distance'), findsOneWidget);

      final testCueFinder = find.text('TEST AUDIO CUE');
      await tester.ensureVisible(testCueFinder);
      await tester.pumpAndSettle();
      expect(testCueFinder, findsOneWidget);

      // Tap Test Audio Cue button
      await tester.tap(testCueFinder);
      await tester.pump();
    });
  });
}
