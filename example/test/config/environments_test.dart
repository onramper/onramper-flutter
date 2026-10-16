import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/config/environments.dart';

void main() {
  const full = {
    'ONRAMPER_DEV_API_KEY': 'pk_test_dev',
    'ONRAMPER_DEV_CLIENT_ID': 'client_dev',
    'ONRAMPER_DEV_DEMO_AUTH_TOKEN': 'token_dev',
    'ONRAMPER_PROD_API_KEY': 'pk_prod',
    'ONRAMPER_PROD_CLIENT_ID': 'client_prod',
    'ONRAMPER_PROD_DEMO_AUTH_TOKEN': 'token_prod',
  };

  test('each environment uses its own keys, SDK environment and endpoint', () {
    final dev = DemoEnvironment.development.resolve(full);
    expect(dev.apiKey, 'pk_test_dev');
    expect(dev.clientId, 'client_dev');
    expect(dev.demoToken, 'token_dev');
    expect(dev.sdkEnvironment, OnramperEnvironment.development);
    expect(dev.sessionEndpoint,
        'https://demo-stg.onramper.dev/demo/create-session');
    expect(dev.missing, isEmpty);

    final prod = DemoEnvironment.production.resolve(full);
    expect(prod.apiKey, 'pk_prod');
    expect(prod.sdkEnvironment, OnramperEnvironment.production);
    expect(prod.sessionEndpoint,
        'https://demo-prod.onramper.com/demo/create-session');
  });

  test('development falls back to the unprefixed legacy keys', () {
    final dev = DemoEnvironment.development.resolve({
      'ONRAMPER_API_KEY': 'pk_legacy',
      'ONRAMPER_CLIENT_ID': 'client_legacy',
      'ONRAMPER_DEMO_AUTH_TOKEN': ' token_legacy ',
    });
    expect(dev.apiKey, 'pk_legacy');
    expect(dev.demoToken, 'token_legacy');
    expect(dev.missing, isEmpty);
  });

  test('production has no legacy fallback and names every missing key', () {
    final prod = DemoEnvironment.production.resolve({
      'ONRAMPER_API_KEY': 'pk_legacy',
      'ONRAMPER_PROD_CLIENT_ID': '  ',
    });
    expect(prod.missing, [
      'ONRAMPER_PROD_API_KEY',
      'ONRAMPER_PROD_CLIENT_ID',
      'ONRAMPER_PROD_DEMO_AUTH_TOKEN',
    ]);
  });
}
