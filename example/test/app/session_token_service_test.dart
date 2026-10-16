import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onramper_flutter_example/app/session_token_service.dart';

void main() {
  test('a stalled create-session request times out with a readable error',
      () async {
    final stalled = MockClient((_) => Completer<http.Response>().future);
    await expectLater(
      SessionTokenService.fetch(
        authToken: 'token-1234',
        endpoint: 'https://example.invalid/create-session',
        client: stalled,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<HttpException>()
          .having((e) => e.message, 'message', contains('timed out'))),
    );
  });

  test('returns the minted session', () async {
    final ok = MockClient((_) async =>
        http.Response('{"sessionId":"s","sessionToken":"t"}', 201));
    final session = await SessionTokenService.fetch(
      authToken: 'token-1234',
      endpoint: 'https://example.invalid/create-session',
      client: ok,
    );
    expect(session.sessionId, 's');
    expect(session.sessionToken, 't');
  });
}
