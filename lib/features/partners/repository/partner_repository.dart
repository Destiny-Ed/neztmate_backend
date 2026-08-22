import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/model/partner_request_model.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';

abstract class PartnerRepository {
  Future<PartnerModel> createPartner(PartnerModel partner);
  Future<PartnerModel> getPartnerById(String id);
  Future<PartnerModel> getPartnerBySlug(String slug);
  Future<List<PartnerModel>> listPartners({bool activeOnly = false});
  Future<PartnerModel> updatePartner(PartnerModel partner);

  Future<PartnerRequestModel> createPartnerRequest(PartnerRequestModel request);
  Future<List<PartnerRequestModel>> listPartnerRequests({String? status});
  Future<PartnerRequestModel> getPartnerRequestById(String id);
  Future<PartnerRequestModel> updatePartnerRequest(PartnerRequestModel request);

  Future<List<NotificationModel>> getPartnerNotifications(String partnerId, {int limit = 30});
  Future<NotificationModel> createPartnerNotification({
    required String partnerId,
    required String title,
    required String body,
    String type,
    Map<String, dynamic>? metadata,
  });
}
