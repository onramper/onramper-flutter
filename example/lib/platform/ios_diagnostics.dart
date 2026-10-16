import 'package:flutter/services.dart';

/// Reads native iOS app identifiers (bundle ID + team ID) via a thin
/// MethodChannel registered in `AppDelegate.swift`. Handy for diagnosing
/// App Attest / partner-allowlist mismatches: the Onramper backend keys
/// allowlists off (teamId, bundleId), so seeing the values the app actually
/// launched with avoids guessing. Also supplies device info for the SDK log
/// files' launch line and excludes the log directory from backups.
class IosDiagnostics {
  static const _channel = MethodChannel('onramper_flutter_example/diagnostics');

  static Future<IosAppIdentifiers> readAppIdentifiers() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('getAppIdentifiers');
    return IosAppIdentifiers(
      bundleId: raw?['bundleId'] as String? ?? 'unknown',
      teamId: raw?['teamId'] as String? ?? 'unknown',
    );
  }

  /// `appVersion=… build=… device=… ios=…` for the log file's launch line.
  /// Never throws: unknown values are `?`.
  static Future<String> launchHeader() async {
    Map<String, dynamic>? raw;
    try {
      raw = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
    } catch (_) {
      raw = null;
    }
    String v(String key) => raw?[key] as String? ?? '?';
    return 'appVersion=${v('appVersion')} build=${v('build')} '
        'device=${v('device')} ios=${v('ios')}';
  }

  /// Keeps the log directory out of iCloud/iTunes backups.
  static Future<void> excludeFromBackup(String path) =>
      _channel.invokeMethod<void>('excludeFromBackup', path);
}

class IosAppIdentifiers {
  const IosAppIdentifiers({required this.bundleId, required this.teamId});
  final String bundleId;
  final String teamId;
}
