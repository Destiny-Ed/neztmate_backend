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
    final newInvite = invite.copyWith(id: docRef.id);
    await docRef.set(newInvite.toMap());
    return newInvite;
  }

  @override
  Future<InviteModel> getInviteById(String id) async {
    final doc = await _invites.doc(id).get();
    if (!doc.exists) throw NotFoundException('Invite', id);
    return InviteModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<InviteModel?> getInviteByLink(String inviteLink) async {
    final snap = await _invites.where('inviteLink', WhereFilter.equal, inviteLink).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return InviteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<List<InviteModel>> getInvitesByInviter(String inviterId) async {
    final snap = await _invites.where('inviterId', WhereFilter.equal, inviterId).get();
    return snap.docs.map((d) => InviteModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> acceptInvite(String id, String inviteeId) async {
    await _invites.doc(id).update({
      'status': 'Accepted',
      // Optionally: link inviteeId to user or update role in user doc
    });
  }

  @override
  Future<void> declineInvite(String id) async {
    await _invites.doc(id).update({'status': 'Declined'});
  }

  @override
  Future<void> deleteInvite(String id) async {
    await _invites.doc(id).delete();
  }
}
