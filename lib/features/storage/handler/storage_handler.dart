import 'dart:convert';

import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/storage/storage_service.dart';
import 'package:shelf/shelf.dart';

class StorageHandler {
  final AppStorageService storageService;

  StorageHandler(this.storageService);

  /// POST /storage/upload
  /// Body JSON:
  /// {
  ///   "fileName": "photo.jpg",
  ///   "contentType": "image/jpeg",   // optional
  ///   "folder": "properties",        // optional: properties|units|tasks|receipts|profiles|...
  ///   "data": "<base64 or data-url>"
  /// }
  Future<Response> upload(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('Unauthorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final fileName = (body['fileName'] as String?)?.trim() ?? '';
      final data = body['data'] as String?;
      final contentType = (body['contentType'] as String?)?.trim() ?? 'application/octet-stream';
      final folder = (body['folder'] as String?)?.trim() ?? 'uploads';

      if (fileName.isEmpty || data == null || data.isEmpty) {
        return badRequest('fileName and data (base64) are required');
      }

      final result = await storageService.uploadBase64(
        base64Data: data,
        fileName: fileName,
        contentType: contentType,
        folder: folder,
        userId: userId,
      );

      return Response.ok(
        jsonEncode({
          'message': 'Upload successful',
          'file': result.toMap(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on ArgumentError catch (e) {
      return badRequest(e.message.toString());
    } catch (e, stack) {
      print('Storage upload error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Upload failed'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// POST /storage/upload-multiple
  /// Body: { "files": [ { fileName, contentType?, folder?, data }, ... ] }
  Future<Response> uploadMultiple(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('Unauthorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final files = body['files'] as List<dynamic>?;
      if (files == null || files.isEmpty) {
        return badRequest('files array is required');
      }
      if (files.length > 10) {
        return badRequest('Maximum 10 files per request');
      }

      final results = <Map<String, dynamic>>[];
      for (final item in files) {
        final map = item as Map<String, dynamic>;
        final fileName = (map['fileName'] as String?)?.trim() ?? '';
        final data = map['data'] as String?;
        if (fileName.isEmpty || data == null || data.isEmpty) {
          return badRequest('Each file requires fileName and data');
        }
        final result = await storageService.uploadBase64(
          base64Data: data,
          fileName: fileName,
          contentType: (map['contentType'] as String?)?.trim() ?? 'application/octet-stream',
          folder: (map['folder'] as String?)?.trim() ?? 'uploads',
          userId: userId,
        );
        results.add(result.toMap());
      }

      return Response.ok(
        jsonEncode({
          'message': 'Upload successful',
          'files': results,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on ArgumentError catch (e) {
      return badRequest(e.message.toString());
    } catch (e, stack) {
      print('Storage multi-upload error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Upload failed'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// DELETE|POST /storage/delete
  /// Body: { "path": "neztmate/..." } OR { "url": "https://..." }
  Future<Response> delete(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('Unauthorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final path = body['path'] as String?;
      final url = body['url'] as String?;

      if ((path == null || path.isEmpty) && (url == null || url.isEmpty)) {
        return badRequest('path or url is required');
      }

      await storageService.delete(path: path, url: url);

      return Response.ok(
        jsonEncode({'message': 'Deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ArgumentError catch (e) {
      return badRequest(e.message.toString());
    } catch (e, stack) {
      print('Storage delete error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Delete failed'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
