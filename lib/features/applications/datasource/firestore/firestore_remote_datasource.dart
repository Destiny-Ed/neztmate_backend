import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/applications/datasource/application_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';

class FirestoreApplicationDataSource implements ApplicationRemoteDataSource {
  final Firestore firestore;
  final PropertyRepository propertyRepository;

  FirestoreApplicationDataSource(this.firestore, this.propertyRepository);

  CollectionReference get _applications => firestore.collection('applications');

  @override
  Future<ApplicationModel> createApplication(ApplicationModel application) async {
    final docRef = _applications.doc();
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
  Future<List<ApplicationModel>> getApplicationsByTenant(String tenantId) async {
    final snap = await _applications.where('tenantId', WhereFilter.equal, tenantId).get();
    return snap.docs.map((d) => ApplicationModel.fromMap(d.data())).toList();
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
      'status': 'Approved',
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
      'status': 'Rejected',
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
      'status': 'Withdrawn',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reason': reason ?? 'Withdrawn by tenant',
    });
  }

  @override
  Future<List<ApplicationModel>> getApplicationsForManagerOrOwner(String userId, String role) async {
    try {
      final snap = await _applications.get();
      if (snap.docs.isEmpty) return [];

      final allApplications = snap.docs
          .map((doc) => ApplicationModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      final filteredApplications = <ApplicationModel>[];

      for (final app in allApplications) {
        try {
          final property = await propertyRepository.getPropertyById(app.propertyId);

          bool shouldInclude = false;

          if (role == 'landowner') {
            shouldInclude = property.landownerId == userId;
          } else if (role == 'manager') {
            shouldInclude = property.managerId == userId;
          }

          if (shouldInclude) {
            filteredApplications.add(app);
          }
        } catch (e) {
          // Skip applications where property can't be loaded
          print('Failed to load property for application ${app.id}: $e');
        }
      }

      return filteredApplications;
    } catch (e, stack) {
      print('Error fetching applications for manager/landowner: $e\n$stack');
      return [];
    }
  }
}
