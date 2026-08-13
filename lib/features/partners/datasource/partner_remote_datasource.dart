import 'package:neztmate_backend/features/partners/model/partner_model.dart';

abstract class PartnerRemoteDataSource {
  Future<PartnerModel> createPartner(PartnerModel partner);
  Future<PartnerModel> getPartnerById(String id);
  Future<PartnerModel> getPartnerBySlug(String slug);
  Future<List<PartnerModel>> listPartners({bool activeOnly = true});
  Future<PartnerModel> updatePartner(PartnerModel partner);
}
