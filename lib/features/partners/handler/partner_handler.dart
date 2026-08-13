import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class PartnerHandler {
  final PartnerRepository partnerRepository;

  PartnerHandler(this.partnerRepository);

  static const defaultPartnerSlug = 'neztmate';

  /// GET /partners/config?slug=neztmate  (public branding)
  Future<Response> getPublicConfig(Request request) async {
    try {
      final slug =
          request.url.queryParameters['slug'] ?? request.headers['x-partner-slug'] ?? defaultPartnerSlug;

      final partner = await partnerRepository.getPartnerBySlug(slug);
      if (!partner.isActive) {
        return Response(403, body: jsonEncode({'message': 'Partner is inactive'}));
      }

      return Response.ok(
        jsonEncode({'partner': partner.toPublicMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, s) {
      print('getPublicConfig: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load partner'}));
    }
  }

  /// GET /partners/me  (auth — from JWT partnerId)
  Future<Response> getMyPartner(Request request) async {
    try {
      final partnerId = request.context['partnerId'] as String?;
      if (partnerId == null || partnerId.isEmpty) {
        final partner = await partnerRepository.getPartnerBySlug(defaultPartnerSlug);
        return Response.ok(jsonEncode({'partner': partner.toPublicMap()}));
      }

      final partner = await partnerRepository.getPartnerById(partnerId);
      return Response.ok(
        jsonEncode({'partner': partner.toPublicMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('getMyPartner: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load partner'}));
    }
  }

  /// GET /partners/<id>
  Future<Response> getPartnerById(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'id required'}));

      final partner = await partnerRepository.getPartnerById(id);
      return Response.ok(jsonEncode({'partner': partner.toPublicMap()}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /partners  (platform admin only — protect later)
  Future<Response> createPartner(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final slug = (body['slug'] as String?)?.trim().toLowerCase();
      final name = (body['name'] as String?)?.trim();

      if (slug == null || slug.isEmpty || name == null || name.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'slug and name are required'}));
      }

      final now = DateTime.now();
      final partner = PartnerModel(
        id: '',
        slug: slug,
        name: name,
        logoUrl: body['logoUrl'] as String?,
        primaryColor: body['primaryColor'] as String? ?? '#008080',
        secondaryColor: body['secondaryColor'] as String?,
        supportEmail: body['supportEmail'] as String?,
        domain: body['domain'] as String?,
        isActive: body['isActive'] as bool? ?? true,
        features: body['features'] != null ? Map<String, dynamic>.from(body['features'] as Map) : {},
        fees: body['fees'] != null ? Map<String, dynamic>.from(body['fees'] as Map) : {},
        createdAt: now,
        updatedAt: now,
      );

      final created = await partnerRepository.createPartner(partner);

      return Response.ok(
        jsonEncode({'message': 'Partner created', 'partner': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, s) {
      print('createPartner: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create partner'}));
    }
  }

  /// GET /partners
  Future<Response> listPartners(Request request) async {
    try {
      final partners = await partnerRepository.listPartners(activeOnly: true);
      return Response.ok(jsonEncode({'partners': partners.map((p) => p.toPublicMap()).toList()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }
}

// Future<void> ensureDefaultPartner(PartnerRepository repo) async {
//   try {
//     await repo.getPartnerBySlug('neztmate');
//   } catch (_) {
//     final now = DateTime.now();
//     await repo.createPartner(
//       PartnerModel(
//         id: '',
//         slug: 'neztmate',
//         name: 'NeztMate',
//         primaryColor: '#008080',
//         supportEmail: 'support@neztmate.com',
//         isActive: true,
//         features: {'applications': true, 'payments': true, 'maintenance': true, 'community': true},
//         fees: {'applicationFee': 0},
//         createdAt: now,
//         updatedAt: now,
//       ),
//     );
//     print('Seeded default partner: neztmate');
//   }
// }
