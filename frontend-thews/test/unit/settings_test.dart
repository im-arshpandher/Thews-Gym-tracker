import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thews/features/settings/presentation/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late SettingsNotifier settingsNotifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settingsNotifier = SettingsNotifier(prefs);
  });

  test('Rest Timer Settings defaults and updates persistence', () async {
    expect(settingsNotifier.state.autoStartRestTimer, true);
    expect(settingsNotifier.state.defaultRestDuration, 90);

    await settingsNotifier.setAutoStartRestTimer(false);
    expect(settingsNotifier.state.autoStartRestTimer, false);
    expect(prefs.getBool('auto_start_rest_timer'), false);

    await settingsNotifier.setDefaultRestDuration(120);
    expect(settingsNotifier.state.defaultRestDuration, 120);
    expect(prefs.getInt('default_rest_duration'), 120);
  });
}
