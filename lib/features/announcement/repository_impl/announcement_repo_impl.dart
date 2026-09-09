import 'package:neztmate_backend/features/announcement/datasource/announcement_remote_datasource.dart';
import 'package:neztmate_backend/features/announcement/models/announcement_model.dart';
import 'package:neztmate_backend/features/announcement/repository/announcement_repository.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  final AnnouncementRemoteDataSource dataSource;

  AnnouncementRepositoryImpl(this.dataSource);

  @override
  Future<AnnouncementModel> create(AnnouncementModel announcement) => dataSource.create(announcement);

  @override
  Future<void> update(AnnouncementModel announcement) => dataSource.update(announcement);

  @override
  Future<void> deactivate(String id) => dataSource.deactivate(id);

  @override
  Future<AnnouncementModel> getById(String id) => dataSource.getById(id);

  @override
  Future<List<AnnouncementModel>> listForAdmin({String? partnerId, bool? activeOnly}) =>
      dataSource.listForAdmin(partnerId: partnerId, activeOnly: activeOnly);

  @override
  Future<List<AnnouncementModel>> listActiveForUser({required String? partnerId, required String role}) =>
      dataSource.listActiveForUser(partnerId: partnerId, role: role);
}
