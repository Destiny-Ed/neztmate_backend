import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/announcement/models/announcement_model.dart';
import 'package:neztmate_backend/features/announcement/repository/announcement_repository.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AnnouncementHandler {
  final AnnouncementRepository repository;

  AnnouncementHandler(this.repository);

  bool _isPlatform(String? role) {
    final r = (role ?? '').toLowerCase();
    return r == 'platform_admin' || r == 'super_admin' || r == 'admin';
  }

  bool _isPartnerAdmin(String? role) {
    return (role ?? '').toLowerCase() == 'partner_admin';
  }

  /// POST /announcements
  Future<Response> create(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final jwtPartnerId = request.context['partnerId'] as String?;

      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }
      if (!_isPlatform(role) && !_isPartnerAdmin(role)) {
        return Response(403, body: jsonEncode({'message': 'Admin only'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final title = (body['title'] as String?)?.trim() ?? '';
      final message = (body['body'] as String?)?.trim() ?? '';
      if (title.isEmpty || message.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'title and body are required'}));
      }

      var audience = (body['audience'] as String?)?.toLowerCase() ?? 'partner';
      var partnerId = body['partnerId'] as String? ?? jwtPartnerId;

      if (_isPartnerAdmin(role)) {
        audience = 'partner';
        partnerId = jwtPartnerId;
        if (partnerId == null || partnerId.isEmpty) {
          return Response(400, body: jsonEncode({'message': 'partnerId required'}));
        }
      }

      if (audience == 'all' && !_isPlatform(role)) {
        return Response(403, body: jsonEncode({'message': 'Only platform can broadcast to all'}));
      }
      if (audience == 'partner' && (partnerId == null || partnerId.isEmpty)) {
        return Response(400, body: jsonEncode({'message': 'partnerId required for partner audience'}));
      }

      final displayMode = (body['displayMode'] as String?)?.toLowerCase() ?? 'dialog';
      if (!['marquee', 'dialog'].contains(displayMode)) {
        return Response(400, body: jsonEncode({'message': 'displayMode must be marquee or dialog'}));
      }

      final priority = (body['priority'] as String?)?.toLowerCase() ?? 'normal';
      final roles = (body['roles'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

      final now = DateTime.now();
      final endsAt = body['endsAt'] != null ? DateTime.tryParse(body['endsAt'].toString()) : null;
      final startsAt = body['startsAt'] != null ? DateTime.tryParse(body['startsAt'].toString()) ?? now : now;

      final created = await repository.create(
        AnnouncementModel(
          id: '',
          title: title,
          body: message,
          audience: audience,
          partnerId: audience == 'all' ? null : partnerId,
          roles: roles,
          displayMode: displayMode,
          priority: priority,
          isActive: true,
          startsAt: startsAt,
          endsAt: endsAt,
          linkUrl: body['linkUrl'] as String?,
          linkLabel: body['linkLabel'] as String?,
          createdBy: userId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Announcement created', 'announcement': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Create announcement error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create announcement'}));
    }
  }

  /// GET /announcements/admin
  Future<Response> listAdmin(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final jwtPartnerId = request.context['partnerId'] as String?;

      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }
      if (!_isPlatform(role) && !_isPartnerAdmin(role)) {
        return Response(403, body: jsonEncode({'message': 'Admin only'}));
      }

      final q = request.url.queryParameters;
      final activeOnly = q['activeOnly'] == 'true';

      String? partnerId;
      if (_isPartnerAdmin(role)) {
        partnerId = jwtPartnerId;
      } else {
        partnerId = q['partnerId'];
      }

      final list = await repository.listForAdmin(partnerId: partnerId, activeOnly: activeOnly ? true : null);

      return Response.ok(
        jsonEncode({'announcements': list.map((a) => a.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('List announcements admin error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load announcements'}));
    }
  }

  /// GET /announcements/active  (mobile app)
  Future<Response> listActive(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = (request.context['role'] as String?) ?? '';
      final partnerId = request.context['partnerId'] as String?;

      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final list = await repository.listActiveForUser(partnerId: partnerId, role: role);

      return Response.ok(
        jsonEncode({'announcements': list.map((a) => a.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('List active announcements error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load announcements'}));
    }
  }

  /// PATCH /announcements/<id>
  Future<Response> update(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final jwtPartnerId = request.context['partnerId'] as String?;
      final id = request.params['id'];

      if (userId == null || id == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }
      if (!_isPlatform(role) && !_isPartnerAdmin(role)) {
        return Response(403, body: jsonEncode({'message': 'Admin only'}));
      }

      final existing = await repository.getById(id);

      if (_isPartnerAdmin(role) && existing.partnerId != jwtPartnerId) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final updated = existing.copyWith(
        title: body['title'] as String? ?? existing.title,
        body: body['body'] as String? ?? existing.body,
        displayMode: body['displayMode'] as String? ?? existing.displayMode,
        priority: body['priority'] as String? ?? existing.priority,
        isActive: body['isActive'] as bool? ?? existing.isActive,
        linkUrl: body['linkUrl'] as String? ?? existing.linkUrl,
        linkLabel: body['linkLabel'] as String? ?? existing.linkLabel,
        endsAt: body['endsAt'] != null ? DateTime.tryParse(body['endsAt'].toString()) : existing.endsAt,
        roles: body['roles'] != null
            ? (body['roles'] as List).map((e) => e.toString()).toList()
            : existing.roles,
        updatedAt: DateTime.now(),
      );

      await repository.update(updated);

      return Response.ok(
        jsonEncode({'message': 'Updated', 'announcement': updated.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Update announcement error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update'}));
    }
  }

  /// DELETE /announcements/<id>
  Future<Response> deactivate(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final jwtPartnerId = request.context['partnerId'] as String?;
      final id = request.params['id'];

      if (userId == null || id == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }
      if (!_isPlatform(role) && !_isPartnerAdmin(role)) {
        return Response(403, body: jsonEncode({'message': 'Admin only'}));
      }

      final existing = await repository.getById(id);
      if (_isPartnerAdmin(role) && existing.partnerId != jwtPartnerId) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      await repository.deactivate(id);

      return Response.ok(
        jsonEncode({'message': 'Announcement turned off'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Deactivate announcement error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to deactivate'}));
    }
  }
}
