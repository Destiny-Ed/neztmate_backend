import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

class FirestorePropertyDataSource implements PropertyRemoteDataSource {
  final Firestore firestore;

  FirestorePropertyDataSource(this.firestore);

  CollectionReference get _properties => firestore.collection('properties');

  Query _withPartner(Query query, String? partnerId) {
    if (partnerId != null && partnerId.isNotEmpty) {
      return query.where('partnerId', WhereFilter.equal, partnerId);
    }
    return query;
  }

  @override
  Future<PropertyModel> createProperty(PropertyModel property) async {
    final docRef = _properties.doc(property.id.isEmpty ? null : property.id);
    final toSave = property.id.isEmpty ? property.copyWith(id: docRef.id) : property;
    await docRef.set(toSave.toMap());
    return toSave;
  }

  @override
  Future<PropertyModel> getPropertyById(String id) async {
    final doc = await _properties.doc(id).get();
    if (!doc.exists) throw NotFoundException('Property', id);
    return PropertyModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId, {String? partnerId}) async {
    var query = _properties.where('landownerId', WhereFilter.equal, landownerId);
    query = _withPartner(query, partnerId);
    final snap = await query.get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PropertyModel>> getPropertiesByManager(String managerId, {String? partnerId}) async {
    var query = _properties.where('managerId', WhereFilter.equal, managerId);
    query = _withPartner(query, partnerId);
    final snap = await query.get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PropertyModel>> getPropertiesByArtisan(String artisanId, {String? partnerId}) async {
    var query = _properties.where('artisanIds', WhereFilter.arrayContains, artisanId);
    query = _withPartner(query, partnerId);
    final snap = await query.get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PropertyModel>> getAllAvailableProperties({required String partnerId}) async {
    final snap = await _properties
        .where('partnerId', WhereFilter.equal, partnerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PropertyModel.fromMap(d.data() as Map<String, dynamic>)).toList();
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
            leaseId: leaseData['id'] ?? doc.id,
            unitNumber: unitData['unitNumber'] ?? 'N/A',
            monthlyRent: (leaseData['monthlyRent'] as num?)?.toDouble() ?? 0.0,
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
    return allTenants.where((t) {
      final s = t.leaseStatus.toLowerCase();
      return s == 'active' ||
          s == 'inactive' ||
          s == 'terminationrequested' ||
          s == 'transferrequested' ||
          s == 'termination_requested' ||
          s == 'transfer_requested' ||
          s == 'pending payment';
    }).toList();
  }

  @override
  Future<List<TenantSummary>> getPastTenantsByProperty(String propertyId) async {
    final allTenants = await getTenantsByProperty(propertyId);
    return allTenants.where((t) {
      final s = t.leaseStatus.toLowerCase();
      return s == 'terminated' || s == 'expired' || s == 'transferred';
    }).toList();
  }

  @override
  Future<void> assignUserToProperty({
    required String propertyId,
    required String userId,
    required String role,
    String? commissionType,
    double? commissionRate,
    double? flatFeeAmount,
    String? flatFeePeriod,
  }) async {
    final updateData = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};

    if (role.toLowerCase() == 'manager') {
      updateData['managerId'] = userId;
      if (commissionType != null) {
        updateData['managerCommissionType'] = commissionType;
        if (commissionType == 'percentage' && commissionRate != null) {
          updateData['managerCommissionRate'] = commissionRate;
        } else if (commissionType == 'flat' || commissionType == 'flat_fee') {
          updateData['managerFlatFeeAmount'] = flatFeeAmount;
          updateData['managerFlatFeePeriod'] = flatFeePeriod ?? 'yearly';
        }
      }
    } else if (role.toLowerCase() == 'artisan') {
      updateData['artisanIds'] = FieldValue.arrayUnion([userId]);
    }

    await _properties.doc(propertyId).update(updateData);
  }

  @override
  Future<void> removeUserFromProperty({
    required String propertyId,
    required String userId,
    required String removedBy,
  }) async {
    final propDoc = await _properties.doc(propertyId).get();
    final data = propDoc.data() as Map<String, dynamic>;

    if (data['managerId'] == userId) {
      await _properties.doc(propertyId).update({
        'managerId': null,
        'updatedAt': DateTime.now().toIso8601String(),
        'removedBy': removedBy,
      });
    } else {
      await _properties.doc(propertyId).update({
        'artisanIds': FieldValue.arrayRemove([userId]),
        'updatedAt': DateTime.now().toIso8601String(),
        'removedBy': removedBy,
      });
    }
  }

  @override
  Future<int> countByOwner(String ownerId, {String? partnerId}) async {
    var query = _properties.where('landownerId', WhereFilter.equal, ownerId);
    query = _withPartner(query, partnerId);
    final snap = await query.get();
    return snap.docs.length;
  }

  @override
  Future<int> countManagersByOwner(String ownerId, {String? partnerId}) async {
    var query = _properties.where('landownerId', WhereFilter.equal, ownerId);
    query = _withPartner(query, partnerId);
    final snap = await query.get();

    return snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final managerId = data['managerId'];
      return managerId != null && managerId.toString().isNotEmpty;
    }).length;
  }

  @override
  Future<int> countArtisansByOwner(String ownerId, {String? partnerId}) async {
    var query = _properties.where('landownerId', WhereFilter.equal, ownerId);
    query = _withPartner(query, partnerId);
    final properties = await query.get();

    final Set<String> artisanIds = {};
    for (var doc in properties.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ids = (data['artisanIds'] as List?)?.cast<String>() ?? [];
      artisanIds.addAll(ids);
    }
    return artisanIds.length;
  }
}
