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
    await _requests.doc(request.id).update(request.toMap());
    return request;
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

  @override
  Future<Map<String, dynamic>> getPartnerAnalytics(String partnerId) async {
    // Properties
    final propertiesSnap = await firestore
        .collection('properties')
        .where('partnerId', WhereFilter.equal, partnerId)
        .get();
    final totalProperties = propertiesSnap.docs.length;

    var totalUnits = 0;
    for (final doc in propertiesSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalUnits += (data['totalUnits'] as num?)?.toInt() ?? 0;
    }

    // Units collection (more accurate if you store units separately)
    try {
      final unitsSnap = await firestore
          .collection('units')
          .where('partnerId', WhereFilter.equal, partnerId)
          .get();
      if (unitsSnap.docs.isNotEmpty) {
        totalUnits = unitsSnap.docs.length;
      }
    } catch (_) {}

    // Active leases
    final leasesSnap = await firestore
        .collection('leases')
        .where('partnerId', WhereFilter.equal, partnerId)
        .where('status', WhereFilter.equal, 'active')
        .get();
    final activeLeases = leasesSnap.docs.length;

    // Pending applications
    final appsSnap = await firestore
        .collection('applications')
        .where('partnerId', WhereFilter.equal, partnerId)
        .where('status', WhereFilter.equal, 'pending')
        .get();
    final pendingApplications = appsSnap.docs.length;

    // Open maintenance (adjust status values to your model)
    var openMaintenance = 0;
    try {
      final maintSnap = await firestore
          .collection('maintenance_requests')
          .where('partnerId', WhereFilter.equal, partnerId)
          .where('status', WhereFilter.equal, 'open')
          .get();
      openMaintenance = maintSnap.docs.length;
    } catch (_) {
      try {
        final maintSnap = await firestore
            .collection('maintenance_requests')
            .where('partnerId', WhereFilter.equal, partnerId)
            .get();
        openMaintenance = maintSnap.docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
          return s != 'completed' && s != 'closed' && s != 'cancelled';
        }).length;
      } catch (_) {}
    }

    // Payments
    double totalReceived = 0;
    double totalWithdrawn = 0;
    var paidCount = 0;
    var pendingPayments = 0;

    final paymentsSnap = await firestore
        .collection('payments')
        .where('partnerId', WhereFilter.equal, partnerId)
        .get();

    for (final doc in paymentsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String?)?.toLowerCase() ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      if (status == 'paid') {
        totalReceived += amount;
        paidCount++;
      } else if (status.contains('pending')) {
        pendingPayments++;
      }
    }

    try {
      final withdrawalsSnap = await firestore
          .collection('withdrawals')
          .where('partnerId', WhereFilter.equal, partnerId)
          .where('status', WhereFilter.equal, 'completed')
          .get();
      for (final doc in withdrawalsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalWithdrawn += (data['amount'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}

    // Active subscriptions count (users in this partner)
    var activeSubscriptions = 0;
    String? topPlan;
    try {
      final subsSnap = await firestore
          .collection('user_subscriptions')
          .where('partnerId', WhereFilter.equal, partnerId)
          .where('status', WhereFilter.equal, 'active')
          .get();
      activeSubscriptions = subsSnap.docs.length;
      if (subsSnap.docs.isNotEmpty) {
        topPlan = (subsSnap.docs.first.data() as Map<String, dynamic>)['planId'] as String?;
      }
    } catch (_) {}

    final withdrawable = totalReceived - totalWithdrawn;
    if (withdrawable < 0) {
      // still return raw numbers; business rules may differ
    }

    return {
      'totalProperties': totalProperties,
      'totalUnits': totalUnits,
      'activeLeases': activeLeases,
      'pendingApplications': pendingApplications,
      'openMaintenance': openMaintenance,
      'paidPaymentsCount': paidCount,
      'pendingPayments': pendingPayments,
      'totalReceived': totalReceived,
      'totalWithdrawn': totalWithdrawn,
      'withdrawableAmount': withdrawable < 0 ? 0.0 : withdrawable,
      'activeSubscriptions': activeSubscriptions,
      'subscriptionPlan': topPlan,
    };
  }

  @override
  Future<Map<String, dynamic>> getPlatformAnalytics() async {
    // Partners
    final partnersSnap = await firestore.collection('partners').get();
    var activePartners = 0;
    var inactivePartners = 0;
    for (final doc in partnersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final active = data['isActive'] as bool? ?? true;
      if (active) {
        activePartners++;
      } else {
        inactivePartners++;
      }
    }

    // Partner requests
    var pendingPartnerRequests = 0;
    var totalPartnerRequests = 0;
    try {
      final reqSnap = await firestore.collection('partner_requests').get();
      totalPartnerRequests = reqSnap.docs.length;
      pendingPartnerRequests = reqSnap.docs.where((d) {
        final s = (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
        return s == 'pending';
      }).length;
    } catch (_) {}

    // Users
    final usersSnap = await firestore.collection('users').get();
    final totalUsers = usersSnap.docs.length;

    // Properties
    final propertiesSnap = await firestore.collection('properties').get();
    final totalProperties = propertiesSnap.docs.length;

    // Active leases
    final leasesSnap = await firestore
        .collection('leases')
        .where('status', WhereFilter.equal, 'active')
        .get();
    final activeLeases = leasesSnap.docs.length;

    // Payment volume (paid only)
    double totalPaymentsVolume = 0;
    final paymentsSnap = await firestore
        .collection('payments')
        .where('status', WhereFilter.equal, 'paid')
        .get();
    // If status casing differs, fetch all and filter
    if (paymentsSnap.docs.isEmpty) {
      final allPay = await firestore.collection('payments').get();
      for (final doc in allPay.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        if (status == 'paid') {
          totalPaymentsVolume += (data['amount'] as num?)?.toDouble() ?? 0;
        }
      }
    } else {
      for (final doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalPaymentsVolume += (data['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    // Active subscriptions
    var activeSubscriptions = 0;
    try {
      final subsSnap = await firestore
          .collection('user_subscriptions')
          .where('status', WhereFilter.equal, 'active')
          .get();
      activeSubscriptions = subsSnap.docs.length;
    } catch (_) {}

    // Pending applications (platform-wide)
    var pendingApplications = 0;
    try {
      final appsSnap = await firestore
          .collection('applications')
          .where('status', WhereFilter.equal, 'pending')
          .get();
      pendingApplications = appsSnap.docs.length;
    } catch (_) {}

    return {
      'totalPartners': partnersSnap.docs.length,
      'activePartners': activePartners,
      'inactivePartners': inactivePartners,
      'totalPartnerRequests': totalPartnerRequests,
      'pendingPartnerRequests': pendingPartnerRequests,
      'totalUsers': totalUsers,
      'totalProperties': totalProperties,
      'activeLeases': activeLeases,
      'totalPaymentsVolume': totalPaymentsVolume,
      'activeSubscriptions': activeSubscriptions,
      'pendingApplications': pendingApplications,
    };
  }
}
