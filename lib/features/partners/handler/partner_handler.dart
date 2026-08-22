import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/model/partner_request_model.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class PartnerHandler {
  final PartnerRepository partnerRepository;

  PartnerHandler(this.partnerRepository);

  static const defaultPartnerSlug = 'neztmate';
  static final _slugRe = RegExp(r'^[a-z0-9-]{3,40}$');
  static final _hexColorRe = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$');

  bool _isPlatformAdmin(Request request) {
    final role = (request.context['role'] as String?)?.toLowerCase() ?? '';
    return role == 'platform_admin' || role == 'super_admin';
  }

  String? _partnerId(Request request) => request.context['partnerId'] as String?;

  Response _json(Object body, {int status = 200}) =>
      Response(status, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});

  //  PUBLIC

  /// GET /partners/config?slug=
  Future<Response> getPublicConfig(Request request) async {
    try {
      final slug =
          (request.url.queryParameters['slug'] ?? request.headers['x-partner-slug'] ?? defaultPartnerSlug)
              .trim()
              .toLowerCase();

      final partner = await partnerRepository.getPartnerBySlug(slug);
      if (!partner.isActive) {
        return _json({'message': 'Partner is inactive'}, status: 403);
      }

      return _json({'partner': partner.toPublicMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('getPublicConfig: $e\n$s');
      return _json({'message': 'Failed to load partner'}, status: 500);
    }
  }

  /// POST /partners/requests
  Future<Response> submitPartnerRequest(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final companyName = (body['companyName'] as String?)?.trim() ?? '';
      final contactName = (body['contactName'] as String?)?.trim() ?? '';
      final email = (body['email'] as String?)?.trim() ?? '';
      final phone = (body['phone'] as String?)?.trim() ?? '';
      final proposedSlug = (body['proposedSlug'] as String?)?.trim().toLowerCase() ?? '';
      final cities = (body['cities'] as String?)?.trim() ?? '';
      final message = (body['message'] as String?)?.trim() ?? '';

      if (companyName.isEmpty || contactName.isEmpty || email.isEmpty || phone.isEmpty) {
        return _json({'message': 'companyName, contactName, email and phone are required'}, status: 400);
      }
      if (!email.contains('@')) {
        return _json({'message': 'Invalid email'}, status: 400);
      }
      if (!_slugRe.hasMatch(proposedSlug)) {
        return _json({'message': 'proposedSlug must be 3-40 chars: a-z, 0-9, hyphen'}, status: 400);
      }
      if (cities.isEmpty || message.isEmpty) {
        return _json({'message': 'cities and message are required'}, status: 400);
      }

      final now = DateTime.now();
      final created = await partnerRepository.createPartnerRequest(
        PartnerRequestModel(
          id: '',
          companyName: companyName,
          contactName: contactName,
          email: email,
          phone: phone,
          proposedSlug: proposedSlug,
          website: (body['website'] as String?)?.trim(),
          cities: cities,
          portfolioSize: body['portfolioSize'] as String?,
          message: message,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Notify platform inbox (partnerId = neztmate platform)
      try {
        await partnerRepository.createPartnerNotification(
          partnerId: defaultPartnerSlug,
          title: 'New partner request',
          body: '$companyName requested slug "$proposedSlug"',
          type: 'partner_admin',
          metadata: {'relatedId': created.id, 'relatedCollection': 'partner_requests'},
        );
      } catch (_) {}

      return _json({'message': 'Request submitted', 'request': created.toMap()});
    } on ValidationException catch (e) {
      return _json({'message': e.message}, status: 400);
    } catch (e, s) {
      print('submitPartnerRequest: $e\n$s');
      return _json({'message': 'Failed to submit request'}, status: 500);
    }
  }

  /// GET /partners/<id>
  Future<Response> getPartnerById(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null || id.isEmpty) return _json({'message': 'id required'}, status: 400);

      final partner = await partnerRepository.getPartnerById(id);
      return _json({'partner': partner.toPublicMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e) {
      return _json({'message': 'Failed'}, status: 500);
    }
  }

  // ——— PARTNER ADMIN ———

  /// GET /partners/me
  Future<Response> getMyPartner(Request request) async {
    try {
      final partnerId = _partnerId(request);
      if (partnerId == null || partnerId.isEmpty) {
        return _json({'message': 'partnerId missing from token'}, status: 403);
      }

      PartnerModel partner;
      try {
        partner = await partnerRepository.getPartnerById(partnerId);
      } on NotFoundException {
        partner = await partnerRepository.getPartnerBySlug(partnerId);
      }

      return _json({'partner': partner.toMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('getMyPartner: $e\n$s');
      return _json({'message': 'Failed to load partner'}, status: 500);
    }
  }

  /// PATCH /partners/me
  Future<Response> updateMyPartner(Request request) async {
    try {
      final partnerId = _partnerId(request);
      if (partnerId == null || partnerId.isEmpty) {
        return _json({'message': 'partnerId required'}, status: 403);
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      var partner = await _resolvePartner(partnerId);

      partner = partner.copyWith(
        supportPhone: body['supportPhone'] as String? ?? partner.supportPhone,
        website: body['website'] as String? ?? partner.website,
        supportEmail: body['supportEmail'] as String? ?? partner.supportEmail,
        domain: body['domain'] as String? ?? partner.domain,
        updatedAt: DateTime.now(),
      );

      final updated = await partnerRepository.updatePartner(partner);
      return _json({'message': 'Partner updated', 'partner': updated.toMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('updateMyPartner: $e\n$s');
      return _json({'message': 'Failed to update'}, status: 500);
    }
  }

  /// PATCH /partners/me/branding
  Future<Response> updateMyBranding(Request request) async {
    try {
      final partnerId = _partnerId(request);
      if (partnerId == null || partnerId.isEmpty) {
        return _json({'message': 'partnerId required'}, status: 403);
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      var partner = await _resolvePartner(partnerId);

      final primary = body['primaryColor'] as String? ?? partner.primaryColor;
      final secondary = body['secondaryColor'] as String? ?? partner.secondaryColor;

      if (!_hexColorRe.hasMatch(primary)) {
        return _json({'message': 'primaryColor must be hex e.g. #0d9488'}, status: 400);
      }
      if (secondary != null && secondary.isNotEmpty && !_hexColorRe.hasMatch(secondary)) {
        return _json({'message': 'secondaryColor must be hex'}, status: 400);
      }

      final name = (body['name'] as String?)?.trim();
      if (name != null && name.isEmpty) {
        return _json({'message': 'name cannot be empty'}, status: 400);
      }

      partner = partner.copyWith(
        name: name ?? partner.name,
        tagline: body['tagline'] as String? ?? partner.tagline,
        primaryColor: primary,
        secondaryColor: secondary,
        logoUrl: body['logoUrl'] as String? ?? partner.logoUrl,
        supportEmail: body['supportEmail'] as String? ?? partner.supportEmail,
        updatedAt: DateTime.now(),
      );

      final updated = await partnerRepository.updatePartner(partner);
      return _json({'message': 'Branding updated', 'partner': updated.toPublicMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('updateMyBranding: $e\n$s');
      return _json({'message': 'Failed to update branding'}, status: 500);
    }
  }

  /// GET /partners/me/notifications
  Future<Response> getMyPartnerNotifications(Request request) async {
    try {
      final partnerId = _partnerId(request);
      if (partnerId == null || partnerId.isEmpty) {
        return _json({'message': 'partnerId required'}, status: 403);
      }

      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '30') ?? 30;
      final list = await partnerRepository.getPartnerNotifications(partnerId, limit: limit.clamp(1, 100));

      return _json({
        'notifications': list.map((n) => n.toMap()).toList(),
        'message': 'Partner notifications loaded',
      });
    } catch (e, s) {
      print('getMyPartnerNotifications: $e\n$s');
      return _json({'message': 'Failed to load notifications'}, status: 500);
    }
  }

  /// POST /partners/me/notifications — partner admin broadcasts to partner inbox
  Future<Response> sendPartnerNotification(Request request) async {
    try {
      final partnerId = _partnerId(request);
      if (partnerId == null || partnerId.isEmpty) {
        return _json({'message': 'partnerId required'}, status: 403);
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final title = (body['title'] as String?)?.trim() ?? '';
      final text = (body['body'] as String?)?.trim() ?? '';

      if (title.isEmpty || text.isEmpty) {
        return _json({'message': 'title and body are required'}, status: 400);
      }

      final created = await partnerRepository.createPartnerNotification(
        partnerId: partnerId,
        title: title,
        body: text,
        type: body['type'] as String? ?? 'partner_admin',
        metadata: body['metadata'] is Map ? Map<String, dynamic>.from(body['metadata'] as Map) : null,
      );

      return _json({'message': 'Notification created', 'notification': created.toMap()});
    } catch (e, s) {
      print('sendPartnerNotification: $e\n$s');
      return _json({'message': 'Failed to send notification'}, status: 500);
    }
  }

  // ——— PLATFORM ADMIN ———

  Future<Response> listPartners(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }
      final activeOnly = request.url.queryParameters['activeOnly'] == 'true';
      final partners = await partnerRepository.listPartners(activeOnly: activeOnly);
      return _json({'partners': partners.map((p) => p.toMap()).toList()});
    } catch (e) {
      return _json({'message': 'Failed to list partners'}, status: 500);
    }
  }

  Future<Response> createPartner(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final slug = (body['slug'] as String?)?.trim().toLowerCase();
      final name = (body['name'] as String?)?.trim();

      if (slug == null || name == null || name.isEmpty) {
        return _json({'message': 'slug and name are required'}, status: 400);
      }
      if (!_slugRe.hasMatch(slug)) {
        return _json({'message': 'slug must be 3-40 chars: a-z, 0-9, hyphen'}, status: 400);
      }

      final primary = body['primaryColor'] as String? ?? '#0d9488';
      if (!_hexColorRe.hasMatch(primary)) {
        return _json({'message': 'primaryColor must be hex'}, status: 400);
      }

      final now = DateTime.now();
      final partner = PartnerModel(
        id: '',
        slug: slug,
        name: name,
        tagline: body['tagline'] as String?,
        logoUrl: body['logoUrl'] as String?,
        primaryColor: primary,
        secondaryColor: body['secondaryColor'] as String?,
        supportEmail: body['supportEmail'] as String?,
        supportPhone: body['supportPhone'] as String?,
        website: body['website'] as String?,
        domain: body['domain'] as String?,
        isActive: body['isActive'] as bool? ?? true,
        features: body['features'] != null ? Map<String, dynamic>.from(body['features'] as Map) : {},
        fees: body['fees'] != null ? Map<String, dynamic>.from(body['fees'] as Map) : {},
        createdAt: now,
        updatedAt: now,
      );

      final created = await partnerRepository.createPartner(partner);
      return _json({'message': 'Partner created', 'partner': created.toMap()});
    } on ValidationException catch (e) {
      return _json({'message': e.message}, status: 400);
    } catch (e, s) {
      print('createPartner: $e\n$s');
      return _json({'message': 'Failed to create partner'}, status: 500);
    }
  }

  Future<Response> updatePartner(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }

      final id = request.params['id'];
      if (id == null) return _json({'message': 'id required'}, status: 400);

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      var partner = await partnerRepository.getPartnerById(id);

      partner = partner.copyWith(
        name: (body['name'] as String?)?.trim() ?? partner.name,
        tagline: body['tagline'] as String? ?? partner.tagline,
        logoUrl: body['logoUrl'] as String? ?? partner.logoUrl,
        primaryColor: body['primaryColor'] as String? ?? partner.primaryColor,
        secondaryColor: body['secondaryColor'] as String? ?? partner.secondaryColor,
        supportEmail: body['supportEmail'] as String? ?? partner.supportEmail,
        supportPhone: body['supportPhone'] as String? ?? partner.supportPhone,
        website: body['website'] as String? ?? partner.website,
        domain: body['domain'] as String? ?? partner.domain,
        features: body['features'] != null
            ? Map<String, dynamic>.from(body['features'] as Map)
            : partner.features,
        fees: body['fees'] != null ? Map<String, dynamic>.from(body['fees'] as Map) : partner.fees,
        updatedAt: DateTime.now(),
      );

      final updated = await partnerRepository.updatePartner(partner);
      return _json({'message': 'Partner updated', 'partner': updated.toMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('updatePartner: $e\n$s');
      return _json({'message': 'Failed to update partner'}, status: 500);
    }
  }

  Future<Response> setPartnerStatus(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }

      final id = request.params['id'];
      if (id == null) return _json({'message': 'id required'}, status: 400);

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final isActive = body['isActive'] as bool?;
      final status = body['status'] as String?; // optional alternate

      if (isActive == null && status == null) {
        return _json({'message': 'isActive or status required'}, status: 400);
      }

      var partner = await partnerRepository.getPartnerById(id);
      final active = isActive ?? (status != 'suspended' && status != 'inactive');
      partner = partner.copyWith(isActive: active, updatedAt: DateTime.now());

      final updated = await partnerRepository.updatePartner(partner);
      return _json({'message': 'Status updated', 'partner': updated.toMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('setPartnerStatus: $e\n$s');
      return _json({'message': 'Failed to update status'}, status: 500);
    }
  }

  Future<Response> listPartnerRequests(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }
      final status = request.url.queryParameters['status'];
      final list = await partnerRepository.listPartnerRequests(status: status);
      return _json({'requests': list.map((r) => r.toMap()).toList()});
    } catch (e, s) {
      print('listPartnerRequests: $e\n$s');
      return _json({'message': 'Failed to list requests'}, status: 500);
    }
  }

  Future<Response> updatePartnerRequest(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }

      final id = request.params['id'];
      if (id == null) return _json({'message': 'id required'}, status: 400);

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      var req = await partnerRepository.getPartnerRequestById(id);

      final status = body['status'] as String?;
      if (status != null && !['pending', 'contacted', 'approved', 'rejected'].contains(status)) {
        return _json({'message': 'Invalid status'}, status: 400);
      }

      req = req.copyWith(
        status: status ?? req.status,
        notes: body['notes'] as String? ?? req.notes,
        updatedAt: DateTime.now(),
      );

      final updated = await partnerRepository.updatePartnerRequest(req);

      // Optional: auto-create partner when approved
      if (status == 'approved') {
        try {
          await partnerRepository.createPartner(
            PartnerModel(
              id: '',
              slug: req.proposedSlug,
              name: req.companyName,
              supportEmail: req.email,
              supportPhone: req.phone,
              website: req.website,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        } on ValidationException {
          // slug may already exist
        }
      }

      return _json({'message': 'Request updated', 'request': updated.toMap()});
    } on NotFoundException catch (e) {
      return _json({'message': e.message}, status: 404);
    } catch (e, s) {
      print('updatePartnerRequest: $e\n$s');
      return _json({'message': 'Failed to update request'}, status: 500);
    }
  }

  Future<PartnerModel> _resolvePartner(String partnerIdOrSlug) async {
    try {
      return await partnerRepository.getPartnerById(partnerIdOrSlug);
    } on NotFoundException {
      return partnerRepository.getPartnerBySlug(partnerIdOrSlug);
    }
  }
}
