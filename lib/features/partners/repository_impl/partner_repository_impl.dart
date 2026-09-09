import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/partners/datasource/partner_remote_datasource.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/model/partner_request_model.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';

class PartnerRepositoryImpl implements PartnerRepository {
  final PartnerRemoteDataSource dataSource;

  PartnerRepositoryImpl(this.dataSource);

  @override
  Future<PartnerModel> createPartner(PartnerModel partner) => dataSource.createPartner(partner);

  @override
  Future<PartnerModel?> getPartnerById(String id) => dataSource.getPartnerById(id);

  @override
  Future<PartnerModel?> getPartnerBySlug(String slug) => dataSource.getPartnerBySlug(slug);

  @override
  Future<List<PartnerModel>> listPartners({bool activeOnly = false}) =>
      dataSource.listPartners(activeOnly: activeOnly);

  @override
  Future<PartnerModel> updatePartner(PartnerModel partner) => dataSource.updatePartner(partner);

  @override
  Future<PartnerRequestModel> createPartnerRequest(PartnerRequestModel request) =>
      dataSource.createPartnerRequest(request);

  @override
  Future<List<PartnerRequestModel>> listPartnerRequests({String? status}) =>
      dataSource.listPartnerRequests(status: status);

  @override
  Future<PartnerRequestModel> getPartnerRequestById(String id) => dataSource.getPartnerRequestById(id);

  @override
  Future<PartnerRequestModel> updatePartnerRequest(PartnerRequestModel request) =>
      dataSource.updatePartnerRequest(request);

  @override
  Future<List<NotificationModel>> getPartnerNotifications(String partnerId, {int limit = 30}) =>
      dataSource.getPartnerNotifications(partnerId, limit: limit);

  @override
  Future<NotificationModel> createPartnerNotification({
    required String partnerId,
    required String title,
    required String body,
    String type = 'partner',
    Map<String, dynamic>? metadata,
  }) => dataSource.createPartnerNotification(
    partnerId: partnerId,
    title: title,
    body: body,
    type: type,
    metadata: metadata,
  );

  @override
  Future<Map<String, dynamic>> getPartnerAnalytics(String partnerId) =>
      dataSource.getPartnerAnalytics(partnerId);

  @override
  Future<Map<String, dynamic>> getPlatformAnalytics() => dataSource.getPlatformAnalytics();

  // Application fee methods

  Future<({bool enabled, double amount})> getApplicationFee(String partnerId) async {
    final partner = await getPartnerById(partnerId);
    if (partner == null) {
      return (enabled: false, amount: 0.0);
    }
    final enabled = partner.fees['applicationFeeEnabled'] == true;
    final amount = (partner.fees['applicationFeeAmount'] as num?)?.toDouble() ?? 0.0;
    if (!enabled || amount <= 0) {
      return (enabled: false, amount: 0.0);
    }
    return (enabled: true, amount: amount);
  }

  Future<PartnerModel> setApplicationFee({
    required String partnerId,
    required bool enabled,
    required double amount,
  }) async {
    final partner = await getPartnerById(partnerId);
    if (partner == null) throw NotFoundException('Partner', partnerId);

    final fees = Map<String, dynamic>.from(partner.fees)
      ..['applicationFeeEnabled'] = enabled
      ..['applicationFeeAmount'] = amount < 0 ? 0 : amount;

    final updated = partner.copyWith(fees: fees, updatedAt: DateTime.now());
    return updatePartner(updated);
  }
}
