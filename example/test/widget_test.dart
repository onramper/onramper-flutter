import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onramper_flutter_example/main.dart';

void main() {
  testWidgets('ExampleApp renders the home scaffold', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Onramper SDK example'), findsOneWidget);
  });
}
