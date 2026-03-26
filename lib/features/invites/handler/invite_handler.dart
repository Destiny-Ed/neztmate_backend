import 'dart:convert';
import 'package:neztmate_backend/features/invites/models/invites_model.dart';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class InviteHandler {
  final InviteRepository repository;

  InviteHandler(this.repository);

  /// POST /invites - Landowner/Manager sends an invite
  Future<Response> sendInvite(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners or managers can send invites'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      if (!body.containsKey('inviteeEmail') || !body.containsKey('role')) {
        return Response(400, body: jsonEncode({'message': 'inviteeEmail and role are required'}));
      }

      final invite = InviteModel.fromMap(body, '').copyWith(
        inviterId: userId,
        createdAt: DateTime.now(),
        status: 'Pending',
        // generate inviteLink if needed (e.g. UUID + domain)
      );

      final created = await repository.createInvite(invite);

      return Response.ok(
        jsonEncode({'message': 'Invite sent successfully', 'invite': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Send invite error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to send invite'}));
    }
  }

  /// GET /invites - Inviter views their sent invites
  Future<Response> getMyInvites(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized();

      final invites = await repository.getInvitesByInviter(userId);

      return Response.ok(
        jsonEncode({'invites': invites.map((i) => i.toMap()).toList(), 'message': 'Your sent invites'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my invites error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load invites'}));
    }
  }

  /// POST /invites/<id>/accept - Invitee accepts invite
  Future<Response> acceptInvite(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final inviteId = request.params['id'];

      if (userId == null || inviteId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user or invite ID'}));
      }

     await repository.getInviteById(inviteId);

      // Optional: check if user is the invitee (email match, or invite link used)

      await repository.acceptInvite(inviteId, userId);

      return Response.ok(jsonEncode({'message': 'Invite accepted - your role has been updated'}));
    } catch (e, stack) {
      print('Accept invite error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to accept invite'}));
    }
  }

  /// POST /invites/<id>/decline - Invitee declines invite
  Future<Response> declineInvite(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final inviteId = request.params['id'];

      if (userId == null || inviteId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user or invite ID'}));
      }

      await repository.declineInvite(inviteId);

      return Response.ok(jsonEncode({'message': 'Invite declined'}));
    } catch (e, stack) {
      print('Decline invite error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to decline invite'}));
    }
  }

  Response unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
