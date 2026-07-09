import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/units/datasource/unit_remote_datasource.dart';
import 'package:neztmate_backend/features/units/models/unit_comment_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class FirestoreUnitDataSource implements UnitRemoteDataSource {
  final Firestore firestore;

  FirestoreUnitDataSource(this.firestore);

  CollectionReference get _units => firestore.collection('units');
  CollectionReference get _unitComments => firestore.collection('unit_comments');

  @override
  Future<UnitModel> createUnit(UnitModel unit) async {
    final docRef = _units.doc(unit.id.isEmpty ? null : unit.id);
    await docRef.set(unit.toMap());
    return unit;
  }

  @override
  Future<UnitModel> getUnitById(String id) async {
    final doc = await _units.doc(id).get();
    if (!doc.exists) throw NotFoundException('Unit', id);
    return UnitModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<UnitModel>> getUnitsByProperty(String propertyId) async {
    final snap = await _units.where('propertyId', WhereFilter.equal, propertyId).get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId) async {
    final snap = await _units
        .where('propertyId', WhereFilter.equal, propertyId)
        .where('status', WhereFilter.equal, 'vacant')
        .where('isListedForRent', WhereFilter.equal, true)
        .get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<UnitModel>> getAvailableUnits({String? propertyId, int? minBedrooms, double? maxRent}) async {
    var query = _units
        .where('status', WhereFilter.equal, 'vacant')
        .where('isListedForRent', WhereFilter.equal, true);

    if (propertyId != null) {
      query = query.where('propertyId', WhereFilter.equal, propertyId);
    }
    if (minBedrooms != null) {
      query = query.where('bedrooms', WhereFilter.greaterThanOrEqual, minBedrooms);
    }
    if (maxRent != null) {
      query = query.where('yearlyRent', WhereFilter.greaterThanOrEqual, maxRent);
    }

    final snap = await query.orderBy('yearlyRent').get();
    return snap.docs.map((d) => UnitModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updateUnit(UnitModel unit) async {
    if (unit.id.isEmpty) {
      throw ValidationException('Unit ID cannot be empty');
    }

    // First check if unit exists
    final docRef = firestore.collection('units').doc(unit.id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw NotFoundException('Unit', unit.id);
    }

    // Optional: Check if unit is available for update (business rule)
    final data = docSnapshot.data() as Map<String, dynamic>;
    final currentTenantId = data['currentTenantId'] as String?;
    final rentDueDate = data['rentDueDate'] != null ? DateTime.tryParse(data['rentDueDate'] as String) : null;

    // Example: Prevent update if occupied and rent not due yet
    if (currentTenantId != null && rentDueDate != null && rentDueDate.isAfter(DateTime.now())) {
      throw ValidationException('Cannot update unit while it is occupied and rent is still due.');
    }

    // Perform the update
    await docRef.update(unit.toMap());
  }

  @override
  Future<void> deleteUnit(String id) async {
    if (id.isEmpty) {
      throw ValidationException('Unit ID cannot be empty');
    }
    // First check if unit exists
    final docRef = firestore.collection('units').doc(id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw NotFoundException('Unit', id);
    }

    // Optional: Check if unit is available for update (business rule)
    final data = docSnapshot.data() as Map<String, dynamic>;
    final currentTenantId = data['currentTenantId'] as String?;
    final rentDueDate = data['rentDueDate'] != null ? DateTime.tryParse(data['rentDueDate'] as String) : null;

    // Example: Prevent update if occupied and rent not due yet
    if (currentTenantId != null && rentDueDate != null && rentDueDate.isAfter(DateTime.now())) {
      throw ValidationException('Cannot delete unit while it is occupied and rent is still due.');
    }
    await _units.doc(id).delete();
  }

  @override
  Future<void> toggleUnitListing(String unitId, bool isListed) async {
    if (unitId.isEmpty) {
      throw ValidationException('Unit ID cannot be empty');
    }

    final docRef = firestore.collection('units').doc(unitId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw NotFoundException('Unit', unitId);
    }

    final data = docSnapshot.data() as Map<String, dynamic>;
    final currentTenantId = data['currentTenantId'] as String?;
    final rentDueDate = data['rentDueDate'] != null ? DateTime.tryParse(data['rentDueDate'] as String) : null;

    // Business Rule: Cannot list if occupied and rent due date has not elapsed
    if (isListed && currentTenantId != null && rentDueDate != null && rentDueDate.isAfter(DateTime.now())) {
      throw ValidationException(
        'Cannot list unit for rent. Unit is currently occupied and rent due date has not elapsed.',
      );
    }

    await docRef.update({
      'isListedForRent': isListed,
      'listedAt': isListed ? DateTime.now().toIso8601String() : null,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateUnitStatus({
    required String unitId,
    required String status,
    String? currentTenantId,
    bool? isListedForRent,
  }) async {
    if (unitId.isEmpty) throw ValidationException('Unit ID cannot be empty');

    final updates = <String, dynamic>{'status': status, 'updatedAt': DateTime.now().toIso8601String()};

    if (currentTenantId != null) updates['currentTenantId'] = currentTenantId;
    if (isListedForRent != null) updates['isListedForRent'] = isListedForRent;

    await firestore.collection('units').doc(unitId).update(updates);
  }

  @override
  Future<void> toggleLike(String unitId, String userId) async {
    final unitDoc = _units.doc(unitId);
    final unit = await unitDoc.get();

    if (!unit.exists) throw NotFoundException('Unit', unitId);

    final currentLikes = (unit.data()?['likes'] as int?) ?? 0;
    final likedBy = (unit.data()?['likedBy'] as List?)?.cast<String>() ?? [];

    final isLiked = likedBy.contains(userId);

    if (isLiked) {
      // Unlike
      await unitDoc.update({
        'likes': currentLikes - 1,
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      // Like
      await unitDoc.update({
        'likes': currentLikes + 1,
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  @override
  Future<void> addComment(UnitCommentModel comment) async {
    final docRef = _unitComments.doc();
    final newComment = comment.copyWith(id: docRef.id);

    await docRef.set(newComment.toMap());

    // Increment comment count on unit
    await _units.doc(comment.unitId).update({'commentsCount': FieldValue.increment(1)});
  }

  @override
  Future<List<UnitCommentModel>> getCommentsForUnit(String unitId) async {
    final snap = await _unitComments
        .where('unitId', WhereFilter.equal, unitId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((doc) => UnitCommentModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  // @override
  // Future<void> updateComment(String commentId, String newComment) async {
  //   await _unitComments.doc(commentId).update({
  //     'comment': newComment,
  //     'updatedAt': DateTime.now().toIso8601String(),
  //   });
  // }

  // @override
  // Future<void> deleteComment(String commentId, String unitId) async {
  //   await _unitComments.doc(commentId).delete();

  //   // Decrement count
  //   await _units.doc(unitId).update({'commentsCount': FieldValue.increment(-1)});
  // }
}
