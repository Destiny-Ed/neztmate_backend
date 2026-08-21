import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/tenants/datasources/tenant_remote_datasource.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_neightbor.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

class FirestoreTenantDataSource implements TenantRemoteDataSource {
  final Firestore firestore;

  FirestoreTenantDataSource(this.firestore);

  @override
  Future<List<TenantSummary>> searchTenants({
    required String query,
    required String userId,
    required String role,
    String? partnerId,
  }) async {
    try {
      final lowerQuery = query.toLowerCase().trim();
      if (lowerQuery.isEmpty) return [];

      final r = role.toLowerCase();

      // Properties this user owns/manages (scoped by partner when provided)
      Query propQuery = firestore.collection('properties');
      if (r == 'landowner') {
        propQuery = propQuery.where('landownerId', WhereFilter.equal, userId);
      } else if (r == 'manager') {
        propQuery = propQuery.where('managerId', WhereFilter.equal, userId);
      } else {
        return [];
      }

      if (partnerId != null && partnerId.isNotEmpty) {
        propQuery = propQuery.where('partnerId', WhereFilter.equal, partnerId);
      }

      final propSnap = await propQuery.get();
      if (propSnap.docs.isEmpty) return [];

      final propertyIds = propSnap.docs.map((d) => d.id).toSet();
      final List<TenantSummary> results = [];
      final seenTenantKeys = <String>{}; // tenantId+leaseId

      // Leases for those properties (batch with `in`, max 30)
      final propIdList = propertyIds.toList();
      for (var i = 0; i < propIdList.length; i += 30) {
        final batch = propIdList.skip(i).take(30).toList();
        final leaseSnap = await firestore
            .collection('leases')
            .where('propertyId', WhereFilter.isIn, batch)
            .get();

        for (final doc in leaseSnap.docs) {
          final leaseData = doc.data() as Map<String, dynamic>;
          final tenantId = leaseData['tenantId'] as String?;
          final unitId = leaseData['unitId'] as String?;
          if (tenantId == null || tenantId.isEmpty) continue;

          final tenantDoc = await firestore.collection('users').doc(tenantId).get();
          if (!tenantDoc.exists) continue;

          final tenantData = tenantDoc.data() as Map<String, dynamic>;
          final fullName = (tenantData['fullName'] as String? ?? '').toLowerCase();
          final email = (tenantData['email'] as String? ?? '').toLowerCase();

          if (!fullName.contains(lowerQuery) && !email.contains(lowerQuery)) {
            continue;
          }

          String unitNumber = leaseData['unitNumber'] as String? ?? 'N/A';
          if (unitId != null && unitId.isNotEmpty) {
            final unitDoc = await firestore.collection('units').doc(unitId).get();
            if (unitDoc.exists) {
              final unitData = unitDoc.data() as Map<String, dynamic>;
              unitNumber = unitData['unitNumber'] as String? ?? unitNumber;
            }
          }

          final key = '$tenantId-${doc.id}';
          if (seenTenantKeys.contains(key)) continue;
          seenTenantKeys.add(key);

          results.add(
            TenantSummary.fromMap({
              'id': tenantId,
              'fullName': tenantData['fullName'],
              'email': tenantData['email'],
              'phone': tenantData['phone'],
              'profilePhotoUrl': tenantData['profilePhotoUrl'],
              'unitId': unitId,
              'unitNumber': unitNumber,
              'monthlyRent': leaseData['monthlyRent'] ?? 0.0,
              'leaseStartDate': leaseData['startDate'],
              'leaseEndDate': leaseData['endDate'],
              'leaseStatus': leaseData['status'],
              'leaseId': leaseData['id'] ?? doc.id,
            }),
          );
        }
      }

      return results;
    } catch (e, s) {
      print('Tenant search error: $e\n$s');
      return [];
    }
  }

  @override
  Future<List<NeighborModel>> getTenantNeighbors(String propertyId, String tenantId) async {
    // Optional: assert property.partnerId matches caller in the handler
    final snapshot = await firestore
        .collection('leases')
        .where('propertyId', WhereFilter.equal, propertyId)
        .where('status', WhereFilter.equal, 'active') // match your stored casing
        .get();

    // If status is stored lowercase 'active', use that instead
    // Prefer querying both if mixed — or normalize on write

    final neighbors = <NeighborModel>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lease = LeaseModel.fromMap(data);
      // if fromMap needs id: LeaseModel.fromMap(data, doc.id)

      if (lease.tenantId == tenantId) continue;

      final tenantDoc = await firestore.collection('users').doc(lease.tenantId).get();
      final unitDoc = await firestore.collection('units').doc(lease.unitId).get();
      if (!tenantDoc.exists || !unitDoc.exists) continue;

      final tenantData = tenantDoc.data() as Map<String, dynamic>;
      final unitData = unitDoc.data() as Map<String, dynamic>;

      neighbors.add(
        NeighborModel(
          userId: lease.tenantId,
          fullName: tenantData['fullName'] ?? '',
          profileImage: tenantData['profilePhotoUrl'],
          unitNumber: unitData['unitNumber'] ?? '',
          phone: tenantData['phone'] ?? '',
          leaseId: lease.id.isNotEmpty ? lease.id : doc.id,
        ),
      );
    }

    return neighbors;
  }
}
