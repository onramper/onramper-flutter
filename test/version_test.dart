import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wrapperVersion matches pubspec.yaml and podspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final podspec = File('ios/onramper_flutter.podspec').readAsStringSync();
    final pubVersion =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!;
    final podVersion =
        RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(podspec)!;
    expect(OnramperClient.wrapperVersion, pubVersion.group(1));
    expect(OnramperClient.wrapperVersion.replaceAll('+', '.'),
        podVersion.group(1));
  });

  test('sdkVersion normalizes a missing native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.onramper_flutter.OnramperHostApi.sdkVersion',
      (_) async => null,
    );
    await expectLater(
        OnramperClient.sdkVersion(),
        throwsA(isA<OnramperError>()
            .having((e) => e.kind, 'kind', OnramperErrorKind.platformFailure)
            .having((e) => e.platformCode, 'platformCode', 'channel-error')));
  });

  test('sdkVersion reads the native value over the host channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.onramper_flutter.OnramperHostApi.sdkVersion',
      (_) async =>
          OnramperHostApi.pigeonChannelCodec.encodeMessage(<Object?>['1.3.1']),
    );
    expect(await OnramperClient.sdkVersion(), '1.3.1');
  });
}
