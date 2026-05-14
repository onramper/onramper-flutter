// Placeholder integration test — the real plugin facade (OnramperClient)
// is implemented in a follow-up task. For now we just smoke-test that the
// public model API can be referenced from an integration test target.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:onramper_sdk/onramper_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public models are importable', (WidgetTester tester) async {
    const config = OnramperConfiguration(apiKey: 'pk', clientId: 'c');
    expect(config.environment, OnramperEnvironment.production);
  });
}
