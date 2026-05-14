import 'package:flutter/material.dart';
import 'package:onramper_sdk/onramper_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Touch a public type so the example exercises the exported API.
    const config = OnramperConfiguration(
      apiKey: 'pk_demo',
      clientId: 'demo',
    );
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('OnramperSDK example')),
        body: Center(
          child: Text('Configured for client: ${config.clientId}'),
        ),
      ),
    );
  }
}
