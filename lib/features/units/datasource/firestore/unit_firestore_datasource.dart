import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/units/datasource/unit_remote_datasource.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class FirestoreUnitDataSource implements UnitRemoteDataSource {
  final Firestore firestore;

  FirestoreUnitDataSource(this.firestore);

  CollectionReference get _units => firestore.collection('units');

  @override
  Future<UnitModel> createUnit(UnitModel unit) async {
    final docRef = _units.doc(unit.id.isEmpty ? null : unit.id);
    await docRef.set(unit.toMap());
    return unit.copyWith(id: docRef.id);
  }

  @override
  Future<UnitModel> getUnitById(String id) async {
    final doc = await _units.doc(id).get();
    if (!doc.exists) throw NotFoundException('Unit', id);
    return UnitModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<UnitModel>> getUnitsByProperty(String propertyId) async {
    final snap = await _units.where('propertyId', WhereFilter.equal, propertyId).get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId) async {
    final snap = await _units
        .where('propertyId', WhereFilter.equal, propertyId)
        .where('status', WhereFilter.equal, 'vacant')
        .get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<UnitModel>> getAvailableUnits({String? propertyId, int? minBedrooms, double? maxRent}) async {
    var query = _units.where('status', WhereFilter.equal, 'vacant');

    if (propertyId != null) {
      query = query.where('propertyId', WhereFilter.equal, propertyId);
    }
    if (minBedrooms != null) {
      query = query.where('bedrooms', WhereFilter.greaterThanOrEqual, minBedrooms);
    }
    if (maxRent != null) {
      query = query.where('monthlyRent', WhereFilter.greaterThanOrEqual, maxRent);
    }

    final snap = await query.orderBy('monthlyRent').get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> updateUnit(UnitModel unit) async {
    await _units.doc(unit.id).update(unit.toMap());
  }

  @override
  Future<void> deleteUnit(String id) async {
    await _units.doc(id).delete();
  }
}
