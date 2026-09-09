import 'package:neztmate_backend/features/announcement/models/announcement_model.dart';

abstract class AnnouncementRemoteDataSource {
  Future<AnnouncementModel> create(AnnouncementModel announcement);
  Future<void> update(AnnouncementModel announcement);
  Future<void> deactivate(String id);
  Future<AnnouncementModel> getById(String id);
  Future<List<AnnouncementModel>> listForAdmin({String? partnerId, bool? activeOnly});
  Future<List<AnnouncementModel>> listActiveForUser({required String? partnerId, required String role});
}
