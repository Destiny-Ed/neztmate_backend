import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/partners/datasource/partner_remote_datasource.dart';
import 'package:neztmate_backend/features/partners/model/partner_model.dart';
import 'package:neztmate_backend/features/partners/model/partner_request_model.dart';

class FirestorePartnerDataSource implements PartnerRemoteDataSource {
  final Firestore firestore;

  FirestorePartnerDataSource(this.firestore);

  CollectionReference get _partners => firestore.collection('partners');
  CollectionReference get _requests => firestore.collection('partner_requests');
  CollectionReference get _notifications => firestore.collection('notifications');

  @override
  Future<PartnerModel> createPartner(PartnerModel partner) async {
    final existing = await _partners.where('slug', WhereFilter.equal, partner.slug).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw ValidationException('Partner slug already exists');
    }

    final docRef = _partners.doc(partner.id.isEmpty ? null : partner.id);
    final created = partner.copyWith(id: docRef.id, updatedAt: DateTime.now());
    await docRef.set(created.toMap());
    return created;
  }

  @override
  Future<PartnerModel> getPartnerById(String id) async {
    final doc = await _partners.doc(id).get();
    if (!doc.exists) throw NotFoundException('Partner', id);
    final partner = PartnerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    if (!partner.isActive) throw unauthorized("Partner $id is inactive. Request blocked.");
    return partner;
  }

  @override
  Future<PartnerModel> getPartnerBySlug(String slug) async {
    final snap = await _partners.where('slug', WhereFilter.equal, slug.trim().toLowerCase()).limit(1).get();
    if (snap.docs.isEmpty) throw NotFoundException('Partner slug', slug);
    final doc = snap.docs.first;
    return PartnerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<List<PartnerModel>> listPartners({bool activeOnly = false}) async {
    Query query = _partners;
    if (activeOnly) {
      query = query.where('isActive', WhereFilter.equal, true);
    }
    final snap = await query.get();
    return snap.docs.map((d) => PartnerModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
  }

  @override
  Future<PartnerModel> updatePartner(PartnerModel partner) async {
    final updated = partner.copyWith(updatedAt: DateTime.now());
    await _partners.doc(partner.id).set(updated.toMap());
    return updated;
  }

  @override
  Future<PartnerRequestModel> createPartnerRequest(PartnerRequestModel request) async {
    final slug = request.proposedSlug.trim().toLowerCase();
    if (slug.length < 3) throw ValidationException('proposedSlug must be at least 3 characters');

    final existingSlug = await _partners.where('slug', WhereFilter.equal, slug).limit(1).get();
    if (existingSlug.docs.isNotEmpty) {
      throw ValidationException('This slug is already taken');
    }

    final pending = await _requests
        .where('email', WhereFilter.equal, request.email.trim().toLowerCase())
        .where('status', WhereFilter.equal, 'pending')
        .limit(1)
        .get();
    if (pending.docs.isNotEmpty) {
      throw ValidationException('You already have a pending partner request');
    }

    final docRef = _requests.doc();
    final created = request.copyWith(
      id: docRef.id,
      proposedSlug: slug,
      email: request.email.trim().toLowerCase(),
      status: 'pending',
      updatedAt: DateTime.now(),
    );
    await docRef.set(created.toMap());
    return created;
  }

  @override
  Future<List<PartnerRequestModel>> listPartnerRequests({String? status}) async {
    Query query = _requests.orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      query = _requests.where('status', WhereFilter.equal, status).orderBy('createdAt', descending: true);
    }
    final snap = await query.limit(100).get();
    return snap.docs.map((d) => PartnerRequestModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
  }

  @override
  Future<PartnerRequestModel> getPartnerRequestById(String id) async {
    final doc = await _requests.doc(id).get();
    if (!doc.exists) throw NotFoundException('PartnerRequest', id);
    return PartnerRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<PartnerRequestModel> updatePartnerRequest(PartnerRequestModel request) async {
    final updated = request.copyWith(updatedAt: DateTime.now());
    await _requests.doc(request.id).set(updated.toMap());
    return updated;
  }

  @override
  Future<List<NotificationModel>> getPartnerNotifications(String partnerId, {int limit = 30}) async {
    final snap = await _notifications
        .where('partnerId', WhereFilter.equal, partnerId)
        .where('type', WhereFilter.equal, 'partner_admin')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) {
      return NotificationModel.fromMap(d.data() as Map<String, dynamic>, d.id);
    }).toList();
  }

  @override
  Future<NotificationModel> createPartnerNotification({
    required String partnerId,
    required String title,
    required String body,
    String type = 'partner_admin',
    Map<String, dynamic>? metadata,
  }) async {
    final docRef = _notifications.doc();
    final notification = NotificationModel(
      id: docRef.id,
      userId: partnerId, // target partner inbox key; or use admin user ids later
      partnerId: partnerId,
      type: type,
      title: title,
      body: body,
      relatedId: metadata?['relatedId'] as String?,
      relatedCollection: metadata?['relatedCollection'] as String?,
      isRead: false,
      createdAt: DateTime.now(),
    );
    await docRef.set(notification.toMap());
    return notification;
  }
}
