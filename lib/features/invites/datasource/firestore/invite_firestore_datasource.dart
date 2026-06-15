import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/invites/datasource/invite_remote_datasource.dart';
import 'package:neztmate_backend/features/invites/models/invites_model.dart';

class FirestoreInviteDataSource implements InviteRemoteDataSource {
  final Firestore firestore;

  FirestoreInviteDataSource(this.firestore);

  CollectionReference get _invites => firestore.collection('invites');

  @override
  Future<InviteModel> createInvite(InviteModel invite) async {
    final docRef = _invites.doc(invite.id.isNotEmpty ? invite.id : null);
    final inviteLink = "https://neztmate.com/invite?${docRef.id}";
    final newInvite = invite.copyWith(id: docRef.id, inviteLink: inviteLink);
    await docRef.set(newInvite.toMap());
    return newInvite;
  }

  @override
  Future<InviteModel> getInviteById(String id) async {
    final doc = await _invites.doc(id).get();
    if (!doc.exists) throw NotFoundException('Invite', id);
    return InviteModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<InviteModel?> getInviteByLink(String inviteLink) async {
    final snap = await _invites.where('inviteLink', WhereFilter.equal, inviteLink).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return InviteModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<InviteModel>> getInvitesByInviter(String inviterId) async {
    final snap = await _invites.where('inviterId', WhereFilter.equal, inviterId).get();
    return snap.docs.map((d) => InviteModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> acceptInvite(String id, String inviteeId) async {
    await _invites.doc(id).update({
      'status': 'Accepted',
      'updatedAt': DateTime.now().toIso8601String(),

      // Optionally: link inviteeId to user or update role in user doc
    });
  }

  @override
  Future<void> declineInvite(String id) async {
    await _invites.doc(id).update({'status': 'Declined', 'updatedAt': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> deleteInvite(String id) async {
    await _invites.doc(id).delete();
  }

  @override
  Future<List<InviteModel>> getInvitesByInviteeEmail(String email) async {
    try {
      final snap = await _invites
          .where('inviteeEmail', WhereFilter.equal, email.toLowerCase())
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final invite = InviteModel.fromMap(data);

        // Auto-update status to Expired if needed
        if (invite.status == 'Pending' && invite.isExpired) {
          _invites.doc(doc.id).update({'status': 'Expired', 'updatedAt': DateTime.now().toIso8601String()});
          return invite.copyWith(status: 'Expired');
        }

        return invite;
      }).toList();
    } catch (e) {
      print('Error fetching invites by email: $e');
      return [];
    }
  }
}
