import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'onramper_sdk_platform_interface.dart';

/// An implementation of [OnramperSdkPlatform] that uses method channels.
class MethodChannelOnramperSdk extends OnramperSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('onramper_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
