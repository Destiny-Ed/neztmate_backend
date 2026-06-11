import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/tenants/datasources/tenant_remote_datasource.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

class FirestoreTenantDataSource implements TenantRemoteDataSource {
  final Firestore firestore;

  FirestoreTenantDataSource(this.firestore);

  @override
  Future<List<TenantSummary>> searchTenants({
    required String query,
    required String userId,
    required String role,
  }) async {
    try {
      final lowerQuery = query.toLowerCase();

      // Get all leases for this landowner/manager
      final leaseSnap = await firestore.collection('leases').get();
      final List<TenantSummary> results = [];

      for (var doc in leaseSnap.docs) {
        final leaseData = doc.data() as Map<String, dynamic>;
        final tenantId = leaseData['tenantId'] as String;
        final propertyId = leaseData['propertyId'] as String;

        // Security: Only show tenants from properties owned/managed by this user
        final propertyDoc = await firestore.collection('properties').doc(propertyId).get();
        if (!propertyDoc.exists) continue;

        final propertyData = propertyDoc.data() as Map<String, dynamic>;
        final isOwner = propertyData['landownerId'] == userId;
        final isManager = propertyData['managerId'] == userId;

        if (!isOwner && !isManager) continue;

        // Fetch tenant details
        final tenantDoc = await firestore.collection('users').doc(tenantId).get();
        if (!tenantDoc.exists) continue;

        final tenantData = tenantDoc.data() as Map<String, dynamic>;
        final fullName = (tenantData['full_name'] as String? ?? '').toLowerCase();
        final email = (tenantData['email'] as String? ?? '').toLowerCase();

        // Search by name or email
        if (fullName.contains(lowerQuery) || email.contains(lowerQuery)) {
          results.add(
            TenantSummary.fromMap({
              'id': tenantId,
              'fullName': tenantData['fullName'],
              'email': tenantData['email'],
              'phone': tenantData['phone'],
              'profilePhotoUrl': tenantData['profilePhotoUrl'],
              'unitId': leaseData['unitId'],
              'unitNumber': leaseData['unitNumber'] ?? 'N/A',
              'monthlyRent': leaseData['monthlyRent'] ?? 0.0,
              'leaseStartDate': leaseData['startDate'],
              'leaseEndDate': leaseData['endDate'],
              'leaseStatus': leaseData['status'],
            }),
          );
        }
      }

      return results;
    } catch (e) {
      print('Tenant search error: $e');
      return [];
    }
  }
}
