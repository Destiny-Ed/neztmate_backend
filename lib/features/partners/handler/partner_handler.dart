import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/model/partner_request_model.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

class PartnerHandler {
  final PartnerRepository partnerRepository;
  final UserRepository userRepository;
  final PasswordService passwordService;

  PartnerHandler(this.partnerRepository, this.userRepository, this.passwordService);

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

      // Optional URL / text fields: null or empty string clears override → site uses defaults
      String? opt(String key) {
        if (!body.containsKey(key)) return null; // omit → keep existing via copyWith below
        final v = body[key];
        if (v == null) return '';
        return v.toString().trim();
      }

      String? nextOptional(String key, String? current) {
        if (!body.containsKey(key)) return current;
        final v = opt(key);
        if (v == null || v.isEmpty) return null; // clear
        return v;
      }

      partner = partner.copyWith(
        name: name ?? partner.name,
        tagline: nextOptional('tagline', partner.tagline),
        primaryColor: primary,
        secondaryColor: (secondary == null || secondary.isEmpty) ? null : secondary,
        logoUrl: nextOptional('logoUrl', partner.logoUrl),
        supportEmail: nextOptional('supportEmail', partner.supportEmail),
        playStoreUrl: nextOptional('playStoreUrl', partner.playStoreUrl),
        appStoreUrl: nextOptional('appStoreUrl', partner.appStoreUrl),
        privacyUrl: nextOptional('privacyUrl', partner.privacyUrl),
        termsUrl: nextOptional('termsUrl', partner.termsUrl),
        copyright: nextOptional('copyright', partner.copyright),
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

  /// GET /partners/me/analytics
  Future<Response> getMyPartnerAnalytics(Request request) async {
    try {
      final partnerId = request.context['partnerId'] as String?;
      if (partnerId == null || partnerId.isEmpty) {
        return Response(
          403,
          body: jsonEncode({'message': 'partnerId required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Ensure partner exists (id or slug)
      try {
        await partnerRepository.getPartnerById(partnerId);
      } on NotFoundException {
        await partnerRepository.getPartnerBySlug(partnerId);
      }

      final analytics = await partnerRepository.getPartnerAnalytics(partnerId);

      return Response.ok(jsonEncode(analytics), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, s) {
      print('getMyPartnerAnalytics: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load partner analytics'}));
    }
  }

  /// GET /platform/analytics
  Future<Response> getPlatformAnalytics(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return _json({'message': 'Platform admin only'}, status: 403);
      }

      final analytics = await partnerRepository.getPlatformAnalytics();

      return Response.ok(jsonEncode(analytics), headers: {'Content-Type': 'application/json'});
    } catch (e, s) {
      print('getPlatformAnalytics: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load platform analytics'}));
    }
  }

  /// GET /partners/public
  Future<Response> listPublicPartners(Request request) async {
    try {
      final partners = await partnerRepository.listPartners(activeOnly: true);
      return Response.ok(
        jsonEncode({'partners': partners.map((p) => p.toPublicMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('listPublicPartners: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to list partners'}));
    }
  }

  /// POST /partners/with-admin  (platform only)
  Future<Response> createPartnerWithAdmin(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return Response(403, body: jsonEncode({'message': 'Platform admin only'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final slug = (body['slug'] as String?)?.trim().toLowerCase() ?? '';
      final name = (body['name'] as String?)?.trim() ?? '';
      final adminEmail = (body['adminEmail'] as String?)?.trim().toLowerCase() ?? '';
      final adminPassword = (body['adminPassword'] as String?) ?? '';
      final adminFullName = (body['adminFullName'] as String?)?.trim() ?? '';

      if (slug.isEmpty || name.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'slug and name are required'}));
      }
      if (!RegExp(r'^[a-z0-9-]{3,40}$').hasMatch(slug)) {
        return Response(400, body: jsonEncode({'message': 'Invalid slug'}));
      }
      if (adminEmail.isEmpty || adminPassword.length < 8 || adminFullName.isEmpty) {
        return Response(
          400,
          body: jsonEncode({'message': 'adminFullName, adminEmail and adminPassword (min 8) are required'}),
        );
      }

      // Unique slug
      final existing = await partnerRepository.getPartnerBySlug(slug);

      // Unique admin email
      try {
        await userRepository.getUserByEmail(adminEmail);
        return Response(409, body: jsonEncode({'message': 'Admin email already registered'}));
      } on NotFoundException {
        // ok
      } catch (_) {
        // if getUserByEmail returns null instead of throw:
      }

      final partner = await partnerRepository.createPartner(
        PartnerModel(
          id: '',
          slug: slug,
          name: name,
          tagline: body['tagline'] as String?,
          primaryColor: body['primaryColor'] as String? ?? '#0d9488',
          secondaryColor: body['secondaryColor'] as String? ?? '#0f766e',
          logoUrl: body['logoUrl'] as String?,
          supportEmail: body['supportEmail'] as String?,
          supportPhone: body['supportPhone'] as String?,
          website: body['websiteUrl'] as String?,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminId = const Uuid().v4();
      final admin = User(
        id: adminId,
        email: adminEmail,
        fullName: adminFullName,
        role: 'partner_admin',
        passwordHash: passwordService.hash(adminPassword),
        partnerId: partner.id.isNotEmpty ? partner.id : slug,
        verifiedIdentity: false,
        verifiedEmployment: false,
        roles: ['partner_admin'],
        rating: 0,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        authProvider: 'email',
        fcmToken: '',
        platform: 'web',
        country: 'NG',
        primaryRole: 'partner_admin',
      );

      await userRepository.createUser(admin);

      return Response.ok(
        jsonEncode({
          'message': 'Partner and admin created. Share the temporary password securely.',
          'partner': partner.toMap(),
          'adminEmail': adminEmail,
          'adminId': adminId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('createPartnerWithAdmin: $e\n$s');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to create partner with admin'}),
      );
    }
  }

  /// POST /partners/requests/<id>/approve
  Future<Response> approvePartnerRequest(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return Response(403, body: jsonEncode({'message': 'Platform admin only'}));
      }

      final id = request.params['id'];
      if (id == null || id.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Request id required'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>? ?? {};
      final req = await partnerRepository.getPartnerRequestById(id);

      if (req.status.toLowerCase() == 'approved') {
        return Response(400, body: jsonEncode({'message': 'Request already approved'}));
      }

      final slug = (req.proposedSlug).trim().toLowerCase();
      final existing = await partnerRepository.getPartnerBySlug(slug);
      if (existing.id.isNotEmpty) {
        return Response(409, body: jsonEncode({'message': 'Slug already taken: $slug'}));
      }
      final partner = await partnerRepository.createPartner(
        PartnerModel(
          id: '',
          slug: slug,
          name: req.companyName,
          tagline: null,
          primaryColor: '#0d9488',
          secondaryColor: '#0f766e',
          supportEmail: req.email,
          website: req.website,
          supportPhone: req.phone,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      String? adminEmail;
      String? adminId;

      final password = (body['adminPassword'] as String?) ?? '';
      final email = ((body['adminEmail'] as String?) ?? req.email).trim().toLowerCase();
      final fullName = ((body['adminFullName'] as String?) ?? req.contactName).trim();

      if (password.isNotEmpty) {
        if (password.length < 8) {
          return Response(400, body: jsonEncode({'message': 'adminPassword min 8 characters'}));
        }
        adminEmail = email;
        adminId = const Uuid().v4();
        await userRepository.createUser(
          User(
            id: adminId,
            email: email,
            fullName: fullName,
            role: 'partner_admin',
            passwordHash: passwordService.hash(password),
            partnerId: partner.id.isNotEmpty ? partner.id : slug,
            verifiedIdentity: false,
            verifiedEmployment: false,
            rating: 0,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
            authProvider: 'email',
            fcmToken: '',
            platform: 'web',
            country: 'NG',
            primaryRole: 'partner_admin',
            roles: ['partner_admin'],
          ),
        );
      }

      final now = DateTime.now();
      final reviewerId = request.context['userId'] as String?;

      await partnerRepository.updatePartnerRequest(
        req.copyWith(
          id: id,
          status: 'approved',
          partnerId: partner.id,
          notes: body['notes'] as String? ?? req.notes,
          reviewedBy: reviewerId,
          reviewedAt: now,
          updatedAt: now,
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': adminId != null
              ? 'Partner approved and admin credentials created'
              : 'Partner approved (no admin login created)',
          'partner': partner.toMap(),
          'adminEmail': adminEmail,
          'adminId': adminId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('approvePartnerRequest: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to approve request'}));
    }
  }

  /// POST /partners/<id>/admin/reset-password
  Future<Response> resetPartnerAdminPassword(Request request) async {
    try {
      if (!_isPlatformAdmin(request)) {
        return Response(403, body: jsonEncode({'message': 'Platform admin only'}));
      }

      final partnerId = request.params['id'];
      if (partnerId == null || partnerId.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Partner id required'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newPassword = (body['newPassword'] as String?) ?? '';
      final adminEmail = (body['adminEmail'] as String?)?.trim().toLowerCase();

      if (newPassword.length < 8) {
        return Response(400, body: jsonEncode({'message': 'newPassword must be at least 8 characters'}));
      }

      // Ensure partner exists
      PartnerModel partner;
      try {
        partner = await partnerRepository.getPartnerById(partnerId);
      } catch (_) {
        partner = await partnerRepository.getPartnerBySlug(partnerId);
      }

      final scopeId = partner.id.isNotEmpty ? partner.id : partner.slug;

      User? target;
      if (adminEmail != null && adminEmail.isNotEmpty) {
        target = await userRepository.getUserByEmail(adminEmail);
        if (target.id.isEmpty || target.partnerId != scopeId && target.partnerId != partner.slug) {
          return Response(404, body: jsonEncode({'message': 'Admin user not found for this partner'}));
        }
      } else {
        // First user with this partnerId (prefer Landowner)
        final users = await userRepository.listUsers(partnerId: scopeId, limit: 50);
        target = users.cast<User?>().firstWhere(
          (u) => u!.role.toLowerCase() == 'landowner' || u.role.toLowerCase() == 'partner_admin',
          orElse: () => users.isNotEmpty ? users.first : null,
        );
        if (target == null) {
          // try slug as partnerId
          final users2 = await userRepository.listUsers(partnerId: partner.slug, limit: 50);
          if (users2.isEmpty) {
            return Response(404, body: jsonEncode({'message': 'No admin user linked to this partner'}));
          }
          target = users2.first;
        }
      }

      await userRepository.updateUser(target.copyWith(passwordHash: passwordService.hash(newPassword)));

      return Response.ok(
        jsonEncode({
          'message': 'Password reset successfully',
          'adminEmail': target.email,
          'adminId': target.id,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('resetPartnerAdminPassword: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to reset password'}));
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
