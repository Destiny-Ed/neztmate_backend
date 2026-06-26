import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/artisan_with_stats.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

class FirestorePropertyDataSource implements PropertyRemoteDataSource {
  final Firestore firestore;
  final MaintenanceRepository maintenanceRepository;

  FirestorePropertyDataSource(this.firestore, this.maintenanceRepository);

  CollectionReference get _properties => firestore.collection('properties');

  @override
  Future<PropertyModel> createProperty(PropertyModel property) async {
    final docRef = _properties.doc(property.id.isEmpty ? null : property.id);
    await docRef.set(property.toMap());
    return property;
  }

  @override
  Future<PropertyModel> getPropertyById(String id) async {
    final doc = await _properties.doc(id).get();
    if (!doc.exists) throw NotFoundException('Property', id);
    return PropertyModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId) async {
    final snap = await _properties.where('landownerId', WhereFilter.equal, landownerId).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<PropertyModel>> getPropertiesByManager(String managerId) async {
    final snap = await _properties.where('managerId', WhereFilter.equal, managerId).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<PropertyModel>> getPropertiesByArtisan(String artisanId) async {
    final snap = await _properties.where('artisanIds', WhereFilter.arrayContains, artisanId).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<PropertyModel>> getAllProperties() async {
    final snap = await _properties.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updateProperty(PropertyModel property) async {
    await _properties.doc(property.id).update(property.toMap());
  }

  @override
  Future<void> deleteProperty(String id) async {
    await _properties.doc(id).delete();
  }

  @override
  Future<List<TenantSummary>> getTenantsByProperty(String propertyId) async {
    try {
      final snap = await firestore
          .collection('leases')
          .where('propertyId', WhereFilter.equal, propertyId)
          .get();

      final List<TenantSummary> tenants = [];

      for (var doc in snap.docs) {
        final leaseData = doc.data() as Map<String, dynamic>;
        final tenantId = leaseData['tenantId'] as String;

        final tenantDoc = await firestore.collection('users').doc(tenantId).get();
        if (!tenantDoc.exists) continue;

        final unitDoc = await firestore.collection('units').doc(leaseData['unitId']).get();
        if (!unitDoc.exists) continue;

        final unitData = unitDoc.data() as Map<String, dynamic>;

        final tenantData = tenantDoc.data() as Map<String, dynamic>;

        tenants.add(
          TenantSummary(
            id: tenantId,
            fullName: tenantData['fullName'] ?? 'Unknown',
            email: tenantData['email'] ?? '',
            phone: tenantData['phone'],
            profilePhotoUrl: tenantData['profilePhotoUrl'],
            unitId: leaseData['unitId'],
            leaseId: leaseData['id'],
            unitNumber: unitData['unitNumber'] ?? 'N/A',
            monthlyRent: (leaseData['yearlyRent'] as num?)?.toDouble() ?? 0.0,
            leaseStartDate: DateTime.parse(leaseData['startDate']),
            leaseEndDate: leaseData['endDate'] != null ? DateTime.parse(leaseData['endDate']) : null,
            leaseStatus: leaseData['status'] ?? 'Unknown',
          ),
        );
      }

      return tenants;
    } catch (e) {
      print('Error fetching tenants by property: $e');
      return [];
    }
  }

  @override
  Future<List<TenantSummary>> getCurrentTenantsByProperty(String propertyId) async {
    final allTenants = await getTenantsByProperty(propertyId);
    return allTenants.where((t) => t.leaseStatus == 'Active').toList();
  }

  @override
  Future<List<TenantSummary>> getPastTenantsByProperty(String propertyId) async {
    final allTenants = await getTenantsByProperty(propertyId);
    return allTenants.where((t) => t.leaseStatus == 'Terminated' || t.leaseStatus == 'Expired').toList();
  }

  @override
  Future<void> assignUserToProperty({
    required String propertyId,
    required String userId,
    required String role,
  }) async {
    await firestore.collection('properties').doc(propertyId).update({
      if (role == 'manager') 'managerId': userId,
      if (role == 'artisan') 'artisanIds': FieldValue.arrayUnion([userId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> removeUserFromProperty({
    required String propertyId,
    required String userId,
    required String removedBy,
  }) async {
    final propDoc = await firestore.collection('properties').doc(propertyId).get();
    final data = propDoc.data() as Map<String, dynamic>;

    if (data['managerId'] == userId) {
      await firestore.collection('properties').doc(propertyId).update({
        'managerId': null,
        'updatedAt': DateTime.now().toIso8601String(),
        'removedBy': removedBy,
      });
    } else {
      await firestore.collection('properties').doc(propertyId).update({
        'artisanIds': FieldValue.arrayRemove([userId]),
        'updatedAt': DateTime.now().toIso8601String(),
        'removedBy': removedBy,
      });
    }
  }
}
