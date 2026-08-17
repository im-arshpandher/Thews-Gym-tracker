import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/features/settings/presentation/settings_provider.dart';
import 'package:thews/main.dart';

void main() {
  testWidgets('App loads cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ThewsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ThewsApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
