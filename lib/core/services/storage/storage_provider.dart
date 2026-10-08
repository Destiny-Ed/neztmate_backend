/// Abstract storage backend. Swap implementations (Firebase, R2, S3, …)
/// without changing handlers or callers.
abstract class StorageProvider {
  String get name;

  /// Upload bytes and return a publicly reachable URL (or signed URL).
  Future<StorageUploadResult> upload({
    required List<int> bytes,
    required String objectPath,
    required String contentType,
    Map<String, String>? metadata,
  });

  /// Delete by storage object path (not the full download URL).
  Future<void> deleteByPath(String objectPath);

  /// Delete by full download URL when possible; no-op if URL is not recognized.
  Future<void> deleteByUrl(String url);
}

class StorageUploadResult {
  final String url;
  final String path;
  final String provider;
  final String? contentType;
  final int? sizeBytes;

  const StorageUploadResult({
    required this.url,
    required this.path,
    required this.provider,
    this.contentType,
    this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
        'url': url,
        'path': path,
        'provider': provider,
        if (contentType != null) 'contentType': contentType,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };
}
