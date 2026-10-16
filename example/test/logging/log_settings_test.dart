import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/logging/log_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to on', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await LogSettings.load()).enabled, isTrue);
  });

  test('persists', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await LogSettings.load();
    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setEnabled(false);
    expect(notified, 1);
    expect((await LogSettings.load()).enabled, isFalse);
  });
}
