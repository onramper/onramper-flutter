import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'onramper_sdk_method_channel.dart';

abstract class OnramperSdkPlatform extends PlatformInterface {
  /// Constructs a OnramperSdkPlatform.
  OnramperSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static OnramperSdkPlatform _instance = MethodChannelOnramperSdk();

  /// The default instance of [OnramperSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelOnramperSdk].
  static OnramperSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OnramperSdkPlatform] when
  /// they register themselves.
  static set instance(OnramperSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
