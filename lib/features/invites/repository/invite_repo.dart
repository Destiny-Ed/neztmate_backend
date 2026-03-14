import 'package:neztmate_backend/features/invites/models/invites_model.dart';

abstract class InviteRepository {
  Future<InviteModel> createInvite(InviteModel invite);
  Future<InviteModel> getInviteById(String id);
  Future<InviteModel?> getInviteByLink(String inviteLink);
  Future<List<InviteModel>> getInvitesByInviter(String inviterId);
  Future<void> acceptInvite(String id, String inviteeId);
  Future<void> declineInvite(String id);
  Future<void> deleteInvite(String id);
}
