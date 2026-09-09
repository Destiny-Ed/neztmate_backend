import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/announcement/datasource/announcement_remote_datasource.dart';
import 'package:neztmate_backend/features/announcement/models/announcement_model.dart';

class FirestoreAnnouncementDataSource implements AnnouncementRemoteDataSource {
  final Firestore firestore;

  FirestoreAnnouncementDataSource(this.firestore);

  CollectionReference get _col => firestore.collection('announcements');

  AnnouncementModel _fromDoc(DocumentSnapshot doc) {
    return AnnouncementModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
  }

  @override
  Future<AnnouncementModel> create(AnnouncementModel announcement) async {
    final ref = _col.doc();
    final now = DateTime.now();
    final created = announcement.copyWith(id: ref.id, createdAt: now, updatedAt: now);
    await ref.set(created.toMap());
    return created;
  }

  @override
  Future<void> update(AnnouncementModel announcement) async {
    await _col.doc(announcement.id).update({
      ...announcement.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deactivate(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) throw NotFoundException('Announcement', id);
    await _col.doc(id).update({'isActive': false, 'updatedAt': DateTime.now().toIso8601String()});
  }

  @override
  Future<AnnouncementModel> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) throw NotFoundException('Announcement', id);
    return _fromDoc(doc);
  }

  @override
  Future<List<AnnouncementModel>> listForAdmin({String? partnerId, bool? activeOnly}) async {
    Query query = _col.orderBy('createdAt', descending: true).limit(100);

    if (partnerId != null && partnerId.isNotEmpty) {
      query = _col
          .where('partnerId', WhereFilter.equal, partnerId)
          .orderBy('createdAt', descending: true)
          .limit(100);
    }

    final snap = await query.get();
    var list = snap.docs.map(_fromDoc).toList();

    if (activeOnly == true) {
      list = list.where((a) => a.isActive).toList();
    }
    return list;
  }

  @override
  Future<List<AnnouncementModel>> listActiveForUser({
    required String? partnerId,
    required String role,
  }) async {
    final now = DateTime.now();
    final snap = await _col.where('isActive', WhereFilter.equal, true).limit(80).get();

    final roleLower = role.toLowerCase();

    final list = snap.docs.map(_fromDoc).where((a) {
      if (a.startsAt.isAfter(now)) return false;
      if (a.endsAt != null && a.endsAt!.isBefore(now)) return false;

      if (a.audience == 'all') {
        // ok
      } else if (a.audience == 'partner') {
        if (partnerId == null || partnerId.isEmpty || a.partnerId != partnerId) {
          return false;
        }
      }

      if (a.roles.isNotEmpty) {
        final allowed = a.roles.map((e) => e.toLowerCase()).toList();
        if (!allowed.contains(roleLower)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (a.priority == 'high' && b.priority != 'high') return -1;
      if (b.priority == 'high' && a.priority != 'high') return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }
}
