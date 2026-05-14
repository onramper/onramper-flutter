
import 'onramper_sdk_platform_interface.dart';

class OnramperSdk {
  Future<String?> getPlatformVersion() {
    return OnramperSdkPlatform.instance.getPlatformVersion();
  }
}
