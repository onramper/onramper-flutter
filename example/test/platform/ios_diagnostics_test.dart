import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/platform/ios_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('onramper_flutter_example/diagnostics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('launchHeader formats device info', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceInfo');
      return {
        'appVersion': '1.0.0',
        'build': '7',
        'device': 'iPhone15,2',
        'ios': '18.0',
      };
    });
    expect(await IosDiagnostics.launchHeader(),
        'appVersion=1.0.0 build=7 device=iPhone15,2 ios=18.0');
  });

  test('launchHeader falls back to ? when the channel is missing', () async {
    expect(await IosDiagnostics.launchHeader(),
        'appVersion=? build=? device=? ios=?');
  });

  test('excludeFromBackup passes the path', () async {
    Object? args;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'excludeFromBackup');
      args = call.arguments;
      return null;
    });
    await IosDiagnostics.excludeFromBackup('/tmp/Logs');
    expect(args, '/tmp/Logs');
  });
}
