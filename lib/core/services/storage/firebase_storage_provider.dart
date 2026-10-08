import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:neztmate_backend/core/services/storage/storage_provider.dart';

/// Firebase / Google Cloud Storage provider using the service-account credentials
/// already used by the backend (same as FCM).
class FirebaseStorageProvider implements StorageProvider {
  FirebaseStorageProvider({
    String? bucketName,
    String? projectId,
  })  : _bucket = bucketName ??
            Platform.environment['FIREBASE_STORAGE_BUCKET'] ??
            (DotEnv()..load())['FIREBASE_STORAGE_BUCKET'] ??
            'next-mate.appspot.com',
        _projectId = projectId ??
            Platform.environment['FIREBASE_PROJECT_ID'] ??
            (DotEnv()..load())['FIREBASE_PROJECT_ID'] ??
            'next-mate';

  final String _bucket;
  final String _projectId;

  AutoRefreshingAuthClient? _client;

  @override
  String get name => 'firebase';

  Future<AutoRefreshingAuthClient> _authClient() async {
    if (_client != null) return _client!;

    final sa = await _loadServiceAccountJson();
    final creds = ServiceAccountCredentials.fromJson(sa);
    _client = await clientViaServiceAccount(creds, const [
      'https://www.googleapis.com/auth/devstorage.full_control',
    ]);
    return _client!;
  }

  static Future<Map<String, dynamic>> _loadServiceAccountJson() async {
    final env = DotEnv()..load();

    final rawJson = Platform.environment['FIREBASE_SERVICE_ACCOUNT_JSON'] ??
        env['FIREBASE_SERVICE_ACCOUNT_JSON'];
    if (rawJson != null && rawJson.trim().startsWith('{')) {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    }

    final path = Platform.environment['FIREBASE_SERVICE_ACCOUNT_PATH'] ??
        env['FIREBASE_SERVICE_ACCOUNT_PATH'];
    if (path == null || path.isEmpty) {
      throw Exception(
        'Firebase service account not found. '
        'Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_PATH',
      );
    }
    if (path.trim().startsWith('{')) {
      return jsonDecode(path) as Map<String, dynamic>;
    }
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Firebase service account file not found at $path');
    }
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<StorageUploadResult> upload({
    required List<int> bytes,
    required String objectPath,
    required String contentType,
    Map<String, String>? metadata,
  }) async {
    final client = await _authClient();
    final encodedName = Uri.encodeComponent(objectPath);
    final uri = Uri.parse(
      'https://storage.googleapis.com/upload/storage/v1/b/$_bucket/o'
      '?uploadType=media&name=$encodedName',
    );

    final response = await client.post(
      uri,
      headers: {
        'Content-Type': contentType,
        if (metadata != null)
          for (final e in metadata.entries) 'x-goog-meta-${e.key}': e.value,
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Firebase Storage upload failed (${response.statusCode}): ${response.body}',
      );
    }

    // Public Firebase download URL (works when object is readable / token not required)
    final downloadUrl =
        'https://firebasestorage.googleapis.com/v0/b/$_bucket/o/$encodedName?alt=media';

    return StorageUploadResult(
      url: downloadUrl,
      path: objectPath,
      provider: name,
      contentType: contentType,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<void> deleteByPath(String objectPath) async {
    final client = await _authClient();
    final encodedName = Uri.encodeComponent(objectPath);
    final uri = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/$_bucket/o/$encodedName',
    );
    final response = await client.delete(uri);
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Firebase Storage delete failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  @override
  Future<void> deleteByUrl(String url) async {
    final path = pathFromUrl(url);
    if (path == null || path.isEmpty) {
      throw Exception('Could not resolve storage path from URL');
    }
    await deleteByPath(path);
  }

  /// Extract object path from a Firebase / GCS download URL.
  String? pathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        final segments = uri.pathSegments;
        final oIndex = segments.indexOf('o');
        if (oIndex >= 0 && oIndex + 1 < segments.length) {
          return Uri.decodeComponent(segments[oIndex + 1]);
        }
      }
      // storage.googleapis.com/{bucket}/{path}
      if (uri.host == 'storage.googleapis.com' && uri.pathSegments.length >= 2) {
        return uri.pathSegments.skip(1).join('/');
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _client?.close();
    _client = null;
  }
}
