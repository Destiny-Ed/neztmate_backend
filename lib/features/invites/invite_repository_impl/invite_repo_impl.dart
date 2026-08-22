import 'package:neztmate_backend/features/invites/datasource/invite_remote_datasource.dart';
import 'package:neztmate_backend/features/invites/models/invites_model.dart';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';

class InviteRepositoryImpl implements InviteRepository {
  final InviteRemoteDataSource dataSource;

  InviteRepositoryImpl(this.dataSource);

  @override
  Future<InviteModel> createInvite(InviteModel invite) => dataSource.createInvite(invite);

  @override
  Future<InviteModel> getInviteById(String id) => dataSource.getInviteById(id);

  @override
  Future<InviteModel?> getInviteByLink(String inviteLink) => dataSource.getInviteByLink(inviteLink);

  @override
  Future<List<InviteModel>> getInvitesByInviter(String inviterId, {String? partnerId}) =>
      dataSource.getInvitesByInviter(inviterId, partnerId: partnerId);
  @override
  Future<int> expireOverdueInvites() => dataSource.expireOverdueInvites();
  @override
  Future<List<InviteModel>> getInvitesByInviteeEmail(String email, {String? partnerId}) =>
      dataSource.getInvitesByInviteeEmail(email, partnerId: partnerId);
  @override
  Future<void> acceptInvite(String id, String inviteeId) => dataSource.acceptInvite(id, inviteeId);

  @override
  Future<void> declineInvite(String id) => dataSource.declineInvite(id);

  @override
  Future<void> deleteInvite(String id) => dataSource.deleteInvite(id);

  @override
  Future<void> withdrawInvite(String id) => dataSource.withdrawInvite(id);
}
