import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';

class PartnerAccessException implements Exception {
  final String message;
  final String code;
  final int statusCode;

  PartnerAccessException(this.message, {this.code = 'PARTNER_ACCESS_DENIED', this.statusCode = 403});

  Map<String, dynamic> toJson() => {'message': message, 'code': code};

  Response toResponse() =>
      Response(statusCode, body: jsonEncode(toJson()), headers: {'Content-Type': 'application/json'});
}

class PartnerAccessService {
  final PartnerRepository partnerRepository;
  final UserRepository userRepository;
  final PropertyRepository propertyRepository;
  final UnitRepository unitRepository;

  PartnerAccessService({
    required this.partnerRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.unitRepository,
  });

  Future<PartnerModel> getPartnerOrThrow(String partnerId) async {
    final partner = await partnerRepository.getPartnerById(partnerId);
    if (partner == null) {
      throw NotFoundException('Partner', partnerId);
    }
    return partner;
  }

  /// Workspace suspended or app disabled
  Future<void> assertAppEnabled(String partnerId) async {
    final partner = await getPartnerOrThrow(partnerId);
    if (!partner.appEnabled) {
      throw PartnerAccessException(
        'This workspace is currently disabled. Please contact support.',
        code: 'PARTNER_APP_DISABLED',
        statusCode: 403,
      );
    }
  }

  Future<void> assertSubscriptionsEnabled(String partnerId) async {
    await assertAppEnabled(partnerId);
    final partner = await getPartnerOrThrow(partnerId);
    if (!partner.subscriptionsEnabled) {
      throw PartnerAccessException(
        'Landowner subscriptions are disabled for this workspace.',
        code: 'PARTNER_SUBSCRIPTIONS_DISABLED',
      );
    }
  }

  Future<void> assertApplicationsEnabled(String partnerId) async {
    await assertAppEnabled(partnerId);
    final partner = await getPartnerOrThrow(partnerId);
    if (!partner.applicationsEnabled) {
      throw PartnerAccessException(
        'Lease applications are disabled for this workspace.',
        code: 'PARTNER_APPLICATIONS_DISABLED',
      );
    }
  }

  Future<void> assertCanRegisterLandowner(String partnerId) async {
    await assertAppEnabled(partnerId);
    final partner = await getPartnerOrThrow(partnerId);
    final max = partner.maxLandowners;
    if (max < 0) return;

    final count = await userRepository.countByPartnerAndRole(partnerId: partnerId, role: 'landowner');
    if (count >= max) {
      throw PartnerAccessException(
        'This workspace has reached its landowner limit ($max).',
        code: 'PARTNER_LANDOWNER_LIMIT',
      );
    }
  }

  Future<void> assertCanCreateProperty(String partnerId) async {
    await assertAppEnabled(partnerId);
    final partner = await getPartnerOrThrow(partnerId);
    final max = partner.maxProperties;
    if (max < 0) return;

    final count = await propertyRepository.countByPartner(partnerId);
    if (count >= max) {
      throw PartnerAccessException(
        'This workspace has reached its property limit ($max).',
        code: 'PARTNER_PROPERTY_LIMIT',
      );
    }
  }

  Future<void> assertCanCreateUnit(String partnerId) async {
    await assertAppEnabled(partnerId);
    final partner = await getPartnerOrThrow(partnerId);
    final max = partner.maxUnits;
    if (max < 0) return;

    final count = await unitRepository.countByPartner(partnerId);
    if (count >= max) {
      throw PartnerAccessException(
        'This workspace has reached its unit limit ($max).',
        code: 'PARTNER_UNIT_LIMIT',
      );
    }
  }

  /// Snapshot for admin / debugging
  Future<Map<String, dynamic>> getAccessSnapshot(String partnerId) async {
    final partner = await getPartnerOrThrow(partnerId);
    final landowners = await userRepository.countByPartnerAndRole(partnerId: partnerId, role: 'landowner');
    final properties = await propertyRepository.countByPartner(partnerId);
    final units = await unitRepository.countByPartner(partnerId);

    return {
      'partnerId': partner.id,
      'isActive': partner.isActive,
      'appEnabled': partner.appEnabled,
      'subscriptionsEnabled': partner.subscriptionsEnabled,
      'applicationsEnabled': partner.applicationsEnabled,
      'limits': {
        'maxLandowners': partner.maxLandowners,
        'maxProperties': partner.maxProperties,
        'maxUnits': partner.maxUnits,
      },
      'usage': {'landowners': landowners, 'properties': properties, 'units': units},
    };
  }
}
