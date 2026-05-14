import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onramper_sdk/onramper_sdk.dart';

/// Mints demo `sessionId`/`sessionToken` pairs by hitting the same endpoint the
/// native iOS demo uses (see `oid-ios-demo/SessionTokenService.swift`). The
/// bearer token is injected at build time via `--dart-define`, never hard-coded.
class SessionTokenService {
  static const _endpoint =
      'https://demo-stg.onramper.dev/demo/create-session';

  static Future<SessionCredentials> fetch({required String authToken}) async {
    if (authToken.isEmpty) {
      throw const FormatException(
        'ONRAMPER_DEMO_AUTH_TOKEN is not set — pass it via --dart-define.',
      );
    }

    final masked = authToken.length <= 8
        ? '****'
        : '${authToken.substring(0, 4)}…${authToken.substring(authToken.length - 4)}';
    debugPrint('SessionTokenService: POST $_endpoint (token=$masked)');

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode != 200) {
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
