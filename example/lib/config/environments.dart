import 'package:onramper_flutter/onramper_flutter.dart';

/// Every `--dart-define` the demo reads. `String.fromEnvironment` needs
/// literal names, so they're listed here once.
const demoDefines = <String, String>{
  'ONRAMPER_DEV_API_KEY': String.fromEnvironment('ONRAMPER_DEV_API_KEY'),
  'ONRAMPER_DEV_CLIENT_ID': String.fromEnvironment('ONRAMPER_DEV_CLIENT_ID'),
  'ONRAMPER_DEV_DEMO_AUTH_TOKEN':
      String.fromEnvironment('ONRAMPER_DEV_DEMO_AUTH_TOKEN'),
  'ONRAMPER_PROD_API_KEY': String.fromEnvironment('ONRAMPER_PROD_API_KEY'),
  'ONRAMPER_PROD_CLIENT_ID': String.fromEnvironment('ONRAMPER_PROD_CLIENT_ID'),
  'ONRAMPER_PROD_DEMO_AUTH_TOKEN':
      String.fromEnvironment('ONRAMPER_PROD_DEMO_AUTH_TOKEN'),
  // Legacy unprefixed keys: Development fallback.
  'ONRAMPER_API_KEY': String.fromEnvironment('ONRAMPER_API_KEY'),
  'ONRAMPER_CLIENT_ID': String.fromEnvironment('ONRAMPER_CLIENT_ID'),
  'ONRAMPER_DEMO_AUTH_TOKEN':
      String.fromEnvironment('ONRAMPER_DEMO_AUTH_TOKEN'),
};

/// Environments the demo can switch between (same table as the RN demo).
enum DemoEnvironment {
  development(
    'Development',
    'DEV',
    OnramperEnvironment.development,
    'https://demo-stg.onramper.dev/demo/create-session',
  ),
  production(
    'Production',
    'PROD',
    OnramperEnvironment.production,
    'https://demo-prod.onramper.com/demo/create-session',
  );

  const DemoEnvironment(
    this.label,
    this._prefix,
    this.sdkEnvironment,
    this.sessionEndpoint,
  );

  final String label;
  final String _prefix;
  final OnramperEnvironment sdkEnvironment;
  final String sessionEndpoint;

  /// Reads this environment's secrets from [defines]. Development falls back
  /// to the unprefixed keys so older `.env` files keep working.
  ResolvedEnvironment resolve(Map<String, String> defines) {
    final missing = <String>[];
    String value(String name) {
      final key = 'ONRAMPER_${_prefix}_$name';
      var v = (defines[key] ?? '').trim();
      if (v.isEmpty && this == DemoEnvironment.development) {
        v = (defines['ONRAMPER_$name'] ?? '').trim();
      }
      if (v.isEmpty) missing.add(key);
      return v;
    }

    return ResolvedEnvironment(
      environment: this,
      apiKey: value('API_KEY'),
      clientId: value('CLIENT_ID'),
      demoToken: value('DEMO_AUTH_TOKEN'),
      missing: List.unmodifiable(missing),
    );
  }
}

/// An environment plus its secrets; [missing] names any unset `.env` keys.
class ResolvedEnvironment {
  const ResolvedEnvironment({
    required this.environment,
    required this.apiKey,
    required this.clientId,
    required this.demoToken,
    required this.missing,
  });

  final DemoEnvironment environment;
  final String apiKey;
  final String clientId;
  final String demoToken;
  final List<String> missing;

  OnramperEnvironment get sdkEnvironment => environment.sdkEnvironment;
  String get sessionEndpoint => environment.sessionEndpoint;
  bool get isComplete => missing.isEmpty;
}
