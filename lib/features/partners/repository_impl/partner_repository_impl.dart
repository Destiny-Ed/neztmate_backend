import 'package:neztmate_backend/features/partners/datasource/partner_remote_datasource.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';

class PartnerRepositoryImpl implements PartnerRepository {
  final PartnerRemoteDataSource dataSource;

  PartnerRepositoryImpl(this.dataSource);

  @override
  Future<PartnerModel> createPartner(PartnerModel partner) => dataSource.createPartner(partner);

  @override
  Future<PartnerModel> getPartnerById(String id) => dataSource.getPartnerById(id);

  @override
  Future<PartnerModel> getPartnerBySlug(String slug) => dataSource.getPartnerBySlug(slug);

  @override
  Future<List<PartnerModel>> listPartners({bool activeOnly = true}) =>
      dataSource.listPartners(activeOnly: activeOnly);

  @override
  Future<PartnerModel> updatePartner(PartnerModel partner) => dataSource.updatePartner(partner);
}
