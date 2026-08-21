import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/applications/datasource/application_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';

class FirestoreApplicationDataSource implements ApplicationRemoteDataSource {
  final Firestore firestore;
  final PropertyRepository propertyRepository;

  FirestoreApplicationDataSource(this.firestore, this.propertyRepository);

  CollectionReference get _applications => firestore.collection('applications');

  @override
  Future<ApplicationModel> createApplication(ApplicationModel application) async {
    final docRef = _applications.doc(application.id.isEmpty ? null : application.id);
    final newApp = application.copyWith(id: docRef.id);
    await docRef.set(newApp.toMap());
    return newApp;
  }

  @override
  Future<ApplicationModel> getApplicationById(String id) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) throw NotFoundException('Application', id);
    return ApplicationModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<ApplicationModel>> getApplicationsByTenant(String tenantId, {String? partnerId}) async {
    var query = _applications.where('tenantId', WhereFilter.equal, tenantId);
    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }
    final snap = await query.get();
    return snap.docs.map((d) => ApplicationModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ApplicationModel>> getApplicationsByUnit(String unitId) async {
    final snap = await _applications.where('unitId', WhereFilter.equal, unitId).get();
    return snap.docs.map((d) => ApplicationModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updateApplication(ApplicationModel application) async {
    final doc = await _applications.doc(application.id).get();
    if (!doc.exists) throw NotFoundException('Application', application.id);

    await _applications.doc(application.id).update(application.toMap());
  }

  @override
  Future<void> deleteApplication(String id) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) throw NotFoundException('Application', id);

    await _applications.doc(id).delete();
  }

  @override
  Future<ApplicationModel> approveApplication(String id, String reviewedBy) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) throw NotFoundException('Application', id);

    await _applications.doc(id).update({
      'status': 'approved',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': reviewedBy,
    });

    final updatedDoc = await _applications.doc(id).get();

    return ApplicationModel.fromMap(updatedDoc.data());
  }

  @override
  Future<void> rejectApplication(String id, String reviewedBy, String? reason) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) throw NotFoundException('Application', id);

    await _applications.doc(id).update({
      'status': 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': reviewedBy,
      'reason': reason,
    });
  }

  @override
  Future<void> withdrawApplication(String id, String tenantId, String? reason) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) throw NotFoundException('Application', id);

    final app = ApplicationModel.fromMap(doc.data() as Map<String, dynamic>);

    if (app.tenantId != tenantId) {
      throw ValidationException('You can only withdraw your own application');
    }

    await _applications.doc(id).update({
      'status': 'withdrawn',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reason': reason ?? 'Withdrawn by tenant',
    });
  }

  @override
  Future<List<ApplicationModel>> getApplicationsForManagerOrOwner(
    String userId,
    String role, {
    String? partnerId,
  }) async {
    try {
      final r = role.toLowerCase();

      //  Properties for this owner/manager (+ partner)
      List<PropertyModel> properties;
      if (r == 'landowner') {
        properties = await propertyRepository.getPropertiesByLandowner(userId, partnerId: partnerId);
      } else if (r == 'manager') {
        properties = await propertyRepository.getPropertiesByManager(userId, partnerId: partnerId);
      } else {
        return [];
      }

      if (properties.isEmpty) return [];

      final propertyIds = properties.map((p) => p.id).toList();
      final results = <ApplicationModel>[];

      //  Applications for those properties (batch `in`, max 30)
      for (var i = 0; i < propertyIds.length; i += 30) {
        final batch = propertyIds.skip(i).take(30).toList();
        var query = _applications.where('propertyId', WhereFilter.isIn, batch);

        if (partnerId != null && partnerId.isNotEmpty) {
          query = query.where('partnerId', WhereFilter.equal, partnerId);
        }

        final snap = await query.get();

        for (final doc in snap.docs) {
          final app = ApplicationModel.fromMap(doc.data() as Map<String, dynamic>);
          final status = app.status.toLowerCase();
          if (status == 'fee_pending' || status == 'withdrawn') continue;
          results.add(app);
        }
      }

      return results;
    } catch (e, stack) {
      print('Error fetching applications for manager/landowner: $e\n$stack');
      return [];
    }
  }
}
