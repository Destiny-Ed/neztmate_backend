import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:neztmate_backend/features/metrics/repository/metrics_repository.dart';
import 'package:shelf/shelf.dart';

class MetricsSettingsHandler {
  final PartnerRepository partnerRepository;
  final MetricsRepository metricsRepository;

  MetricsSettingsHandler({required this.partnerRepository, required this.metricsRepository});

  bool _isPlatform(String? role) {
    final r = (role ?? '').toLowerCase();
    return r == 'platform_admin' || r == 'super_admin' || r == 'admin';
  }

  bool _isPartnerAdmin(String? role) {
    final r = (role ?? '').toLowerCase();
    return r == 'partner_admin' || r == 'landowner';
  }

  /// GET /settings/application-fee?partnerId=
  Future<Response> getApplicationFee(Request request) async {
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

      String? partnerId;
      if (_isPlatform(role)) {
        partnerId = request.url.queryParameters['partnerId'];
        if (partnerId == null || partnerId.isEmpty) {
          return Response(400, body: jsonEncode({'message': 'partnerId query is required for platform'}));
        }
      } else {
        partnerId = jwtPartnerId;
        if (partnerId == null || partnerId.isEmpty) {
          return Response(400, body: jsonEncode({'message': 'partnerId missing on token'}));
        }
      }

      final partner = await partnerRepository.getPartnerById(partnerId);
      if (partner == null) throw NotFoundException('Partner', partnerId);

      final enabled = partner.fees['applicationFeeEnabled'] == true;
      final amount = (partner.fees['applicationFeeAmount'] as num?)?.toDouble() ?? 0.0;

      return Response.ok(
        jsonEncode({
          'partnerId': partner.id,
          'enabled': enabled,
          'amount': amount,
          'applicationFeeEnabled': enabled,
          'applicationFeeAmount': amount,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, s) {
      return handleAppException(e, s);
    } catch (e, s) {
      print('getApplicationFee: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load application fee'}));
    }
  }

  /// PUT /settings/application-fee
  /// body: { enabled: bool, amount: number, partnerId?: string }
  Future<Response> updateApplicationFee(Request request) async {
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
      final enabled = body['enabled'] == true || body['applicationFeeEnabled'] == true;
      final amount =
          (body['amount'] as num?)?.toDouble() ?? (body['applicationFeeAmount'] as num?)?.toDouble() ?? 0.0;

      if (amount < 0) {
        return Response(400, body: jsonEncode({'message': 'amount cannot be negative'}));
      }

      String? partnerId;
      if (_isPlatform(role)) {
        partnerId = body['partnerId'] as String?;
        if (partnerId == null || partnerId.isEmpty) {
          return Response(400, body: jsonEncode({'message': 'partnerId is required'}));
        }
      } else {
        partnerId = jwtPartnerId;
        if (partnerId == null || partnerId.isEmpty) {
          return Response(400, body: jsonEncode({'message': 'partnerId missing on token'}));
        }
      }

      final partner = await partnerRepository.getPartnerById(partnerId);
      if (partner == null) throw NotFoundException('Partner', partnerId);

      final fees = Map<String, dynamic>.from(partner.fees)
        ..['applicationFeeEnabled'] = enabled
        ..['applicationFeeAmount'] = amount;

      final updated = await partnerRepository.updatePartner(
        partner.copyWith(fees: fees, updatedAt: DateTime.now()),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Application fee settings saved',
          'partnerId': updated.id,
          'enabled': enabled,
          'amount': amount,
          'fees': updated.fees,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, s) {
      return handleAppException(e, s);
    } catch (e, s) {
      print('updateApplicationFee: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to save application fee'}));
    }
  }

  /// GET /metrics/revenue?partnerId=
  Future<Response> getRevenueMetrics(Request request) async {
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

      String? partnerId;
      if (_isPlatform(role)) {
        partnerId = request.url.queryParameters['partnerId']; // null = all
      } else {
        partnerId = jwtPartnerId;
        if (partnerId == null || partnerId.isEmpty) {
          return Response(400, body: jsonEncode({'message': 'partnerId missing on token'}));
        }
      }

      final metrics = await metricsRepository.getRevenueMetrics(partnerId: partnerId);

      return Response.ok(jsonEncode(metrics), headers: {'Content-Type': 'application/json'});
    } catch (e, s) {
      print('getRevenueMetrics: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load revenue metrics'}));
    }
  }
}
