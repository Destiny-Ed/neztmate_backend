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
    return unit;
  }

  @override
  Future<UnitModel> getUnitById(String id) async {
    final doc = await _units.doc(id).get();
    if (!doc.exists) throw NotFoundException('Unit', id);
    return UnitModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<UnitModel>> getUnitsByProperty(String propertyId) async {
    final snap = await _units.where('propertyId', WhereFilter.equal, propertyId).get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId) async {
    final snap = await _units
        .where('propertyId', WhereFilter.equal, propertyId)
        .where('status', WhereFilter.equal, 'vacant')
        .get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data())).toList();
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
      query = query.where('yearlyRent', WhereFilter.greaterThanOrEqual, maxRent);
    }

    final snap = await query.orderBy('yearlyRent').get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updateUnit(UnitModel unit) async {
    if (unit.id.isEmpty) {
      throw ValidationException('Unit ID cannot be empty');
    }

    // First check if unit exists
    final docRef = firestore.collection('units').doc(unit.id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw NotFoundException('Unit', unit.id);
    }

    // Optional: Check if unit is available for update (business rule)
    final data = docSnapshot.data() as Map<String, dynamic>;
    final currentTenantId = data['currentTenantId'] as String?;
    final rentDueDate = data['rentDueDate'] != null ? DateTime.tryParse(data['rentDueDate'] as String) : null;

    // Example: Prevent update if occupied and rent not due yet
    if (currentTenantId != null && rentDueDate != null && rentDueDate.isAfter(DateTime.now())) {
      throw ValidationException('Cannot update unit while it is occupied and rent is still due.');
    }

    // Perform the update
    await docRef.update(unit.toMap());
  }

  @override
  Future<void> deleteUnit(String id) async {
    if (id.isEmpty) {
      throw ValidationException('Unit ID cannot be empty');
    }
    // First check if unit exists
    final docRef = firestore.collection('units').doc(id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw NotFoundException('Unit', id);
    }

    // Optional: Check if unit is available for update (business rule)
    final data = docSnapshot.data() as Map<String, dynamic>;
    final currentTenantId = data['currentTenantId'] as String?;
    final rentDueDate = data['rentDueDate'] != null ? DateTime.tryParse(data['rentDueDate'] as String) : null;

    // Example: Prevent update if occupied and rent not due yet
    if (currentTenantId != null && rentDueDate != null && rentDueDate.isAfter(DateTime.now())) {
      throw ValidationException('Cannot delete unit while it is occupied and rent is still due.');
    }
    await _units.doc(id).delete();
  }

  @override
  Future<void> toggleUnitListing(String unitId, bool isListed) async {
    if (unitId.isEmpty) {
      throw ValidationException('Unit ID cannot be empty');
    }

    final docRef = firestore.collection('units').doc(unitId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw NotFoundException('Unit', unitId);
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    final currentTenantId = data['currentTenantId'] as String?;
    final rentDueDate = data['rentDueDate'] != null ? DateTime.tryParse(data['rentDueDate'] as String) : null;

    // Business Rule: Cannot list if occupied and rent due date has not elapsed
    if (isListed && currentTenantId != null && rentDueDate != null && rentDueDate.isAfter(DateTime.now())) {
      throw ValidationException(
        'Cannot list unit for rent. Unit is currently occupied and rent due date has not elapsed.',
      );
    }

    await docRef.update({
      'isListedForRent': isListed,
      'listedAt': isListed ? DateTime.now().toIso8601String() : null,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
