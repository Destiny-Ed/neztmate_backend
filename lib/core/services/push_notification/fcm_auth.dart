import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FcmAuth {
  /// Cached client so we don't mint a token on every push
  static AutoRefreshingAuthClient? _client;

  /// Returns a valid OAuth access token for FCM HTTP v1
  static Future<String> fcmAccessTokenFromServiceAccount() async {
    if (_client != null) {
      return _client!.credentials.accessToken.data;
    }

    final Map<String, dynamic> serviceAccountJson = await _loadServiceAccountJson();

    final creds = ServiceAccountCredentials.fromJson(serviceAccountJson);

    _client = await clientViaServiceAccount(creds, const [
      'https://www.googleapis.com/auth/firebase.messaging',
    ]);

    return _client!.credentials.accessToken.data;
  }

  static Future<Map<String, dynamic>> _loadServiceAccountJson() async {
    final env = DotEnv()..load();

    // Prefer full JSON in env (Render/production)
    final rawJson =
        Platform.environment['FIREBASE_SERVICE_ACCOUNT_JSON'] ?? env['FIREBASE_SERVICE_ACCOUNT_JSON'];

    if (rawJson != null && rawJson.trim().startsWith('{')) {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    }

    // Local file path
    final path =
        Platform.environment['FIREBASE_SERVICE_ACCOUNT_PATH'] ??
        env['FIREBASE_SERVICE_ACCOUNT_PATH'];

    if (path == null || path.isEmpty) {
      throw Exception(
        'Firebase service account not found. '
        'Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_PATH',
      );
    }

    // Some hosts put the entire JSON string in FIREBASE_SERVICE_ACCOUNT_PATH
    if (path.trim().startsWith('{')) {
      return jsonDecode(path) as Map<String, dynamic>;
    }

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Firebase service account file not found at $path');
    }

    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  /// Call on shutdown if you want to close the HTTP client
  static void dispose() {
    _client?.close();
    _client = null;
  }
}
