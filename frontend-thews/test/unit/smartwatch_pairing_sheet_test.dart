import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/features/running/presentation/widgets/smartwatch_pairing_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.thews.app/wearable'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_blue_plus/methods'),
      (call) async => null,
    );
  });

  group('SmartwatchPairingSheet Widget Tests', () {
    testWidgets('Renders pairing sheet with BLE radar scan and simulator section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SmartwatchPairingSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('HEART RATE & WATCH PAIRING'), findsOneWidget);
      expect(find.text('TESTING / SIMULATED SENSOR'), findsOneWidget);
      expect(find.text('START SIMULATED SENSOR'), findsOneWidget);

      // Tap simulation button
      await tester.tap(find.text('START SIMULATED SENSOR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Should now render connected state with live BPM and Disconnect button
      expect(find.text('DISCONNECT SENSOR'), findsOneWidget);
      expect(find.text('CALORIES BURNED'), findsOneWidget);

      // Tap disconnect
      await tester.tap(find.text('DISCONNECT SENSOR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('START SIMULATED SENSOR'), findsOneWidget);
    });
  });
}
