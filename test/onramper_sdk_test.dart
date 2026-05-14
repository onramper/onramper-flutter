import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/onramper_sdk.dart';
import 'package:onramper_sdk/onramper_sdk_platform_interface.dart';
import 'package:onramper_sdk/onramper_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOnramperSdkPlatform
    with MockPlatformInterfaceMixin
    implements OnramperSdkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final OnramperSdkPlatform initialPlatform = OnramperSdkPlatform.instance;

  test('$MethodChannelOnramperSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOnramperSdk>());
  });

  test('getPlatformVersion', () async {
    OnramperSdk onramperSdkPlugin = OnramperSdk();
    MockOnramperSdkPlatform fakePlatform = MockOnramperSdkPlatform();
    OnramperSdkPlatform.instance = fakePlatform;

    expect(await onramperSdkPlugin.getPlatformVersion(), '42');
  });
}
