import 'package:flutter/services.dart';

/// Reads native iOS app identifiers (bundle ID + team ID) via a thin
/// MethodChannel registered in `AppDelegate.swift`. Handy for diagnosing
/// App Attest / partner-allowlist mismatches: the Onramper backend keys
/// allowlists off (teamId, bundleId), so seeing the values the app actually
/// launched with avoids guessing.
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
}

class IosAppIdentifiers {
  const IosAppIdentifiers({required this.bundleId, required this.teamId});
  final String bundleId;
  final String teamId;
}
