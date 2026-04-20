import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/applications/datasource/application_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';

class FirestoreApplicationDataSource implements ApplicationRemoteDataSource {
  final Firestore firestore;

  FirestoreApplicationDataSource(this.firestore);

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
    return ApplicationModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<ApplicationModel>> getApplicationsByTenant(String tenantId) async {
    final snap = await _applications.where('tenantId', WhereFilter.equal, tenantId).get();
    return snap.docs.map((d) => ApplicationModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<ApplicationModel>> getApplicationsByUnit(String unitId) async {
    final snap = await _applications.where('unitId', WhereFilter.equal, unitId).get();
    return snap.docs.map((d) => ApplicationModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> updateApplication(ApplicationModel application) async {
    await _applications.doc(application.id).update(application.toMap());
  }

  @override
  Future<void> deleteApplication(String id) async {
    await _applications.doc(id).delete();
  }

  @override
  Future<void> approveApplication(String id, String reviewedBy) async {
    await _applications.doc(id).update({
      'status': 'Approved',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': reviewedBy,
    });
  }

  @override
  Future<void> rejectApplication(String id, String reviewedBy, String? reason) async {
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

    final app = ApplicationModel.fromMap(doc.data() as Map<String, dynamic>, id);

    if (app.tenantId != tenantId) {
      throw ValidationException('You can only withdraw your own application');
    }

    await _applications.doc(id).update({
      'status': 'Withdrawn',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewReason': reason ?? 'Withdrawn by tenant',
    });
  }
}
