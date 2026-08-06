import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class UploadPdfService {
  /// Upload a local PDF file (or bytes) to Firebase Storage and return the public download URL.
  ///
  /// [pdfPathOrUrl] can be:
  /// - a local file path (e.g. /tmp/lease_xxx.pdf)
  /// - already a remote URL (returned as-is)
  static Future<String?> uploadPdfToStorage(
    String pdfPathOrUrl, {
    String folder = 'leases',
    String? fileName,
  }) async {
    return pdfPathOrUrl;
    try {
      // Already a remote URL → nothing to upload
      if (pdfPathOrUrl.startsWith('http://') || pdfPathOrUrl.startsWith('https://')) {
        return pdfPathOrUrl;
      }

      final file = File(pdfPathOrUrl);
      if (!await file.exists()) {
        print('UploadPdfService: file not found → $pdfPathOrUrl');
        return null;
      }

      final bytes = await file.readAsBytes();
      final name = fileName ?? 'lease_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final objectPath = '$folder/$name';

      final storageBucket = "env['FIREBASE_STORAGE_BUCKET'] ?? 'next-mate.appspot.com'";

      // Firebase Storage upload via REST (simple + works with service account access token)
      final uploadUrl = Uri.parse(
        'https://storage.googleapis.com/upload/storage/v1/b/$storageBucket/o'
        '?uploadType=media&name=${Uri.encodeComponent(objectPath)}',
      );

      final accessToken = await _getAccessToken(); // see below
      if (accessToken == null) return null;

      final response = await http.post(
        uploadUrl,
        headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/pdf'},
        body: bytes,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('UploadPdfService failed: ${response.statusCode} ${response.body}');
        return null;
      }

      // Public download URL (bucket must allow read, or use a signed URL instead)
      final encodedPath = Uri.encodeComponent(objectPath);
      return 'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encodedPath?alt=media';
    } catch (e, stack) {
      print('UploadPdfService error: $e\n$stack');
      return null;
    }
  }

  /// Upload from raw bytes (when PDF is generated in memory)
  static Future<String?> uploadPdfBytes(Uint8List bytes, {String folder = 'leases', String? fileName}) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      p.join(tempDir.path, fileName ?? 'lease_${DateTime.now().millisecondsSinceEpoch}.pdf'),
    );
    await tempFile.writeAsBytes(bytes);
    try {
      return await uploadPdfToStorage(tempFile.path, folder: folder, fileName: fileName);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  /// TODO: replace with your real token source
  /// - From Google service account credentials
  /// - Or from dart_firebase_admin / googleapis_auth
  static Future<String?> _getAccessToken() async {
    // Example with googleapis_auth + service account JSON env
    // final credentials = ServiceAccountCredentials.fromJson(jsonDecode(serviceAccountJson));
    // final client = await clientViaServiceAccount(credentials, [StorageApi.devstorageReadWriteScope]);
    // return client.credentials.accessToken.data;
    return Platform.environment['GCP_ACCESS_TOKEN'];
  }
}
