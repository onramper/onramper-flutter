import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onramper_flutter/onramper_flutter.dart';

/// Mints demo `sessionId`/`sessionToken` pairs from the selected environment's
/// Onramper demo endpoint. The bearer token is injected at build time via
/// `--dart-define`, never hard-coded.
///
/// In production your backend would call
/// `POST {upstream}/partners/v2/{apiKey}/client-sessions` signed with your
/// Ed25519 partner key — see `doc/BACKEND_SESSION_ENDPOINT.md` in the plugin
/// repo for a reference implementation.
class SessionTokenService {
  static Future<SessionCredentials> fetch({
    required String authToken,
    required String endpoint,
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (authToken.isEmpty) {
      throw const FormatException(
        'The demo auth token for this environment is not set — add it to '
        'example/.env (see .env.example).',
      );
    }

    final masked = authToken.length <= 8
        ? '****'
        : '${authToken.substring(0, 4)}…${authToken.substring(authToken.length - 4)}';
    debugPrint('SessionTokenService: POST $endpoint (token=$masked)');

    final post = client?.post ?? http.post;
    final http.Response response;
    try {
      response = await post(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'scope': ['quotes:read', 'checkout:read', 'checkout:write'],
        }),
      ).timeout(timeout);
    } on TimeoutException {
      // Without this a stalled network leaves the demo initializing forever.
      throw HttpException(
          'create-session timed out after ${timeout.inSeconds}s');
    }

    if (response.statusCode != 201) {
      throw HttpException(
        'create-session ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('create-session: non-object JSON response.');
    }
    final sessionId = body['sessionId'];
    final sessionToken = body['sessionToken'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        sessionToken is! String ||
        sessionToken.isEmpty) {
      throw const FormatException(
        'create-session: response missing sessionId / sessionToken.',
      );
    }

    return SessionCredentials(sessionId: sessionId, sessionToken: sessionToken);
  }
}
