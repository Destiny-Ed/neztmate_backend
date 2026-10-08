import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:neztmate_backend/core/services/storage/firebase_storage_provider.dart';
import 'package:neztmate_backend/core/services/storage/storage_provider.dart';
import 'package:uuid/uuid.dart';

/// Facade used by handlers. Selects the active provider via STORAGE_PROVIDER env
/// (default: firebase). Future providers (r2, s3, …) plug in here.
class AppStorageService {
  AppStorageService({StorageProvider? provider}) : _provider = provider ?? _resolveProvider();

  final StorageProvider _provider;
  final _uuid = const Uuid();

  StorageProvider get provider => _provider;

  static StorageProvider _resolveProvider() {
    final env = DotEnv()..load();
    final name = (Platform.environment['STORAGE_PROVIDER'] ??
            env['STORAGE_PROVIDER'] ??
            'firebase')
        .toLowerCase()
        .trim();

    switch (name) {
      case 'firebase':
      case 'gcs':
      case 'google':
        return FirebaseStorageProvider();
      // case 'r2':
      //   return R2StorageProvider(...);
      default:
        print('Unknown STORAGE_PROVIDER="$name", falling back to firebase');
        return FirebaseStorageProvider();
    }
  }

  /// Build a safe object path under neztmate/{folder}/{userId}/...
  String buildObjectPath({
    required String folder,
    required String fileName,
    String? userId,
  }) {
    final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_\-/]'), '_');
    final ext = _extensionOf(fileName);
    final base = _uuid.v4();
    final name = ext.isEmpty ? base : '$base.$ext';
    final userPart = (userId != null && userId.isNotEmpty) ? '$userId/' : '';
    return 'neztmate/${safeFolder.isEmpty ? 'uploads' : safeFolder}/$userPart$name';
  }

  Future<StorageUploadResult> uploadBytes({
    required List<int> bytes,
    required String fileName,
    String contentType = 'application/octet-stream',
    String folder = 'uploads',
    String? userId,
    Map<String, String>? metadata,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError('File bytes cannot be empty');
    }
    // Soft limit ~15 MB to protect memory on the server
    const maxBytes = 15 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw ArgumentError('File too large (max 15MB)');
    }

    final path = buildObjectPath(folder: folder, fileName: fileName, userId: userId);
    return _provider.upload(
      bytes: bytes,
      objectPath: path,
      contentType: contentType.isEmpty ? _guessContentType(fileName) : contentType,
      metadata: metadata,
    );
  }

  Future<StorageUploadResult> uploadBase64({
    required String base64Data,
    required String fileName,
    String contentType = 'application/octet-stream',
    String folder = 'uploads',
    String? userId,
  }) {
    // Allow data URLs: data:image/png;base64,....
    var raw = base64Data;
    var resolvedType = contentType;
    if (raw.startsWith('data:') && raw.contains(',')) {
      final header = raw.substring(0, raw.indexOf(','));
      raw = raw.substring(raw.indexOf(',') + 1);
      final match = RegExp(r'data:([^;]+)').firstMatch(header);
      if (match != null && (contentType.isEmpty || contentType == 'application/octet-stream')) {
        resolvedType = match.group(1) ?? resolvedType;
      }
    }
    final bytes = base64Decode(raw);
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: resolvedType,
      folder: folder,
      userId: userId,
    );
  }

  Future<void> delete({String? path, String? url}) async {
    if (path != null && path.isNotEmpty) {
      await _provider.deleteByPath(path);
      return;
    }
    if (url != null && url.isNotEmpty) {
      await _provider.deleteByUrl(url);
      return;
    }
    throw ArgumentError('path or url is required');
  }

  static String _extensionOf(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i < 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1).toLowerCase();
  }

  static String _guessContentType(String fileName) {
    switch (_extensionOf(fileName)) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
