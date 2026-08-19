import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thews/core/database/app_database.dart';
import 'package:thews/core/theme/app_colors.dart';
import 'package:thews/core/utils/gpx_parser.dart';
import 'package:thews/features/running/presentation/animated_route_flyover_screen.dart';
import 'package:thews/features/running/presentation/widgets/gradient_route_painter.dart';
import 'package:thews/features/running/presentation/widgets/run_share_card.dart';

void main() {
  group('Phase 4: SlopeGradientUtils & Route Painter Unit Tests', () {
    test('calculateGradePercent computes accurate slope percentage', () {
      final p1 = GpxPoint(
        latitude: 37.7749,
        longitude: -122.4194,
        elevation: 10.0,
        timestamp: DateTime(2026, 1, 1, 8, 0, 0),
      );
      final p2 = GpxPoint(
        latitude: 37.7758, // ~100m north
        longitude: -122.4194,
        elevation: 20.0, // +10m climb
        timestamp: DateTime(2026, 1, 1, 8, 0, 30),
      );

      final grade = SlopeGradientUtils.calculateGradePercent(p1, p2);
      expect(grade, greaterThan(8.0)); // Steep climb
      expect(SlopeGradientUtils.getSlopeColor(grade), equals(const Color(0xFFFF1744)));
    });

    test('getSlopeColor maps downhill, flat, roll, and climb grades correctly', () {
      // Downhill (< -3%)
      expect(SlopeGradientUtils.getSlopeColor(-5.0), equals(const Color(0xFF00E5FF)));
      // Flat (0%)
      expect(SlopeGradientUtils.getSlopeColor(0.0, isDark: true), equals(AppColors.primaryVolt));
      // Rolling (5%)
      expect(SlopeGradientUtils.getSlopeColor(5.0), equals(const Color(0xFFFFD600)));
      // Climb (10%)
      expect(SlopeGradientUtils.getSlopeColor(10.0), equals(const Color(0xFFFF1744)));
    });

    test('buildSlopeGradientPolylines returns polylines for valid waypoints', () {
      final waypoints = [
        GpxPoint(latitude: 37.7749, longitude: -122.4194, elevation: 10.0, timestamp: DateTime.now()),
        GpxPoint(latitude: 37.7759, longitude: -122.4194, elevation: 15.0, timestamp: DateTime.now()),
        GpxPoint(latitude: 37.7769, longitude: -122.4194, elevation: 8.0, timestamp: DateTime.now()),
      ];

      final polylines = SlopeGradientUtils.buildSlopeGradientPolylines(waypoints);
      expect(polylines.length, equals(2));
    });
  });

  group('Phase 4: Social Share Studio & Route Overlay Widget Tests', () {
    final sampleActivity = RunActivityData(
      id: 99,
      workoutId: null,
      activityType: 'run',
      startTime: DateTime(2026, 8, 17, 7, 30),
      distanceMeters: 5200.0,
      durationSeconds: 1560,
      avgPaceSecondsPerKm: 300.0,
      elevationGainMeters: 85.0,
      gpxData: '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk><name>Morning 5K</name><trkseg>
    <trkpt lat="37.7749" lon="-122.4194"><ele>10.0</ele><time>2026-08-17T07:30:00Z</time></trkpt>
    <trkpt lat="37.7800" lon="-122.4200"><ele>25.0</ele><time>2026-08-17T07:45:00Z</time></trkpt>
    <trkpt lat="37.7850" lon="-122.4210"><ele>15.0</ele><time>2026-08-17T07:56:00Z</time></trkpt>
  </trkseg></trk>
</gpx>''',
    );

    testWidgets('RunShareCardDialog renders with preset and aspect choices', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RunShareCardDialog(activity: sampleActivity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOCIAL SHARE STUDIO'), findsOneWidget);
      expect(find.text('9:16 Story'), findsOneWidget);
      expect(find.text('1:1 Square'), findsOneWidget);
      expect(find.text('Route-Only'), findsOneWidget);
      expect(find.text('SHARE CARD'), findsOneWidget);
    });

    testWidgets('RunShareCardDialog switches to Route-Only overlay mode with transparent switch', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RunShareCardDialog(activity: sampleActivity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Route-Only chip
      final routeOnlyChip = find.text('Route-Only');
      await tester.ensureVisible(routeOnlyChip);
      await tester.tap(routeOnlyChip);
      await tester.pumpAndSettle();

      expect(find.text('Transparent Canvas'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('AnimatedRouteFlyoverScreen loads with telemetry HUD and transport scrubber', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnimatedRouteFlyoverScreen(
              activityId: 99,
              initialActivity: sampleActivity,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('RUN 3D FLYOVER'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
