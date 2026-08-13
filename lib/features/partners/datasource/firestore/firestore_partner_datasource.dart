import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/partners/datasource/partner_remote_datasource.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';

class FirestorePartnerDataSource implements PartnerRemoteDataSource {
  final Firestore firestore;

  FirestorePartnerDataSource(this.firestore);

  CollectionReference get _partners => firestore.collection('partners');

  @override
  Future<PartnerModel> createPartner(PartnerModel partner) async {
    final existing = await _partners.where('slug', WhereFilter.equal, partner.slug).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw ValidationException('Partner slug already exists');
    }

    final docRef = _partners.doc(partner.id.isEmpty ? null : partner.id);
    final created = partner.copyWith(id: docRef.id, updatedAt: DateTime.now());
    await docRef.set(created.toMap());
    return created;
  }

  @override
  Future<PartnerModel> getPartnerById(String id) async {
    final doc = await _partners.doc(id).get();
    if (!doc.exists) throw NotFoundException('Partner', id);
    return PartnerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<PartnerModel> getPartnerBySlug(String slug) async {
    final snap = await _partners.where('slug', WhereFilter.equal, slug).limit(1).get();
    if (snap.docs.isEmpty) throw NotFoundException('Partner slug', slug);
    final doc = snap.docs.first;
    return PartnerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<List<PartnerModel>> listPartners({bool activeOnly = true}) async {
    Query query = _partners;
    if (activeOnly) {
      query = query.where('isActive', WhereFilter.equal, true);
    }
    final snap = await query.get();
    return snap.docs.map((d) => PartnerModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
  }

  @override
  Future<PartnerModel> updatePartner(PartnerModel partner) async {
    await _partners.doc(partner.id).update({
      ...partner.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return partner.copyWith(updatedAt: DateTime.now());
  }
}
