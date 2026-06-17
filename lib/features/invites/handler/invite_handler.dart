import 'dart:convert';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/invites/models/invites_model.dart';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class InviteHandler {
  final InviteRepository repository;
  final UserRepository userRepository;
  final PropertyRepository propertyRepository;
  final NotificationRepository notificationRepository;

  InviteHandler(this.repository, this.userRepository, this.propertyRepository, this.notificationRepository);

  /// POST /invites - Send new invite (expires in 5 days) Send new invite with duplicate check
  /// POST /invites - Send new invite with smart validation
  Future<Response> sendInvite(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners or managers can send invites'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final newPropertyIds = (body['propertyIds'] as List?)?.cast<String>();
      final inviteeEmail = body['inviteeEmail'] as String?;
      final inviteeRole = body['inviteeRole'] as String?;
      final message = body['message'] as String?;

      if (inviteeEmail == null || inviteeRole == null) {
        return badRequest('inviteeEmail and inviteeRole are required');
      }

      if (newPropertyIds == null || newPropertyIds.isEmpty) {
        return badRequest('At least one propertyId is required');
      }

      final normalizedEmail = inviteeEmail.toLowerCase();

      // 1. Check for existing active invites
      final existingInvites = await repository.getInvitesByInviteeEmail(normalizedEmail);

      if (existingInvites.isNotEmpty) {
        for (var existing in existingInvites) {
          if (existing.status == 'Pending' || existing.status == 'Accepted') {
            final overlapping = newPropertyIds
                .where((pid) => (existing.propertyIds ?? []).contains(pid))
                .toList();

            if (overlapping.isNotEmpty) {
              return Response(
                409,
                body: jsonEncode({
                  'message': 'An active invite already exists for this email on some of these properties.',
                  'existingInviteId': existing.id,
                  'status': existing.status,
                  'overlappingProperties': overlapping,
                }),
              );
            }
          }
        }
      }

      // 2. Check if user already exists and is assigned to any property
      final existingUser = await userRepository.getUserByEmail(normalizedEmail);

      // if (existingUser != null) {
      for (var propertyId in newPropertyIds) {
        final property = await propertyRepository.getPropertyById(propertyId);
        // if (property == null) continue;

        bool alreadyAssigned = false;

        if (inviteeRole.toLowerCase() == 'manager' && property.managerId == existingUser.id) {
          alreadyAssigned = true;
        } else if (inviteeRole.toLowerCase() == 'artisan' &&
            property.artisanIds != null &&
            property.artisanIds!.contains(existingUser.id)) {
          alreadyAssigned = true;
        }

        if (alreadyAssigned) {
          return Response(
            409,
            body: jsonEncode({
              'message': 'This user is already assigned as $inviteeRole on property: $propertyId',
              'userId': existingUser.id,
              'propertyId': propertyId,
              'currentRole': inviteeRole,
            }),
          );
        }
      }
      // }

      // All validations passed → Create invite
      final expiresAt = DateTime.now().add(const Duration(days: 5));

      final invite = InviteModel(
        id: '',
        inviterId: userId,
        inviteeEmail: normalizedEmail,
        role: inviteeRole,
        propertyIds: newPropertyIds,
        message: message ?? "Hello, I would like you to join as $inviteeRole.",
        status: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      final created = await repository.createInvite(invite);

      return Response.ok(
        jsonEncode({'message': 'Invite sent successfully (expires in 5 days)', 'invite': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Send invite error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to send invite'}));
    }
  }

  /// GET /invites - Get my sent invites
  Future<Response> getMyInvites(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null) return unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners/managers can view sent invites'}));
      }

      final invites = await repository.getInvitesByInviter(userId);
      final enriched = await _enrichInvites(invites);

      return Response.ok(
        jsonEncode({'invites': enriched, 'message': 'Sent invites loaded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my invites error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /invites/requests - Invites sent to current user (Artisan, Manager, etc.)
  Future<Response> getInviteRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;

      if (userId == null) return unauthorized();

      final user = await userRepository.getUserById(userId);

      final invites = await repository.getInvitesByInviteeEmail(user.email);

      final enriched = await _enrichInvites(invites);

      return Response.ok(
        jsonEncode({'invites': enriched, 'message': 'Invites sent to you', 'count': enriched.length}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get invite requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /invites/<id> - Get single invite by ID
  Future<Response> getInviteById(Request request) async {
    try {
      final inviteId = request.params['id'];
      if (inviteId == null) return badRequest('Invite ID is required');

      final invite = await repository.getInviteById(inviteId);
      final enriched = (await _enrichInvites([invite])).first;

      return Response.ok(jsonEncode({'invite': enriched}), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('Get invite by id error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /invites/<id>/accept - Invitee accepts invite
  Future<Response> acceptInvite(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final inviteId = request.params['id'];

      if (userId == null || inviteId == null) {
        return badRequest('Missing invite ID');
      }

      final invite = await repository.getInviteById(inviteId);

      if (invite.isExpired) {
        return Response(400, body: jsonEncode({'message': 'This invite has expired'}));
      }

      if (invite.status != 'Pending') {
        return Response(400, body: jsonEncode({'message': 'This invite has already been processed'}));
      }

      // Auto-assign user to properties
      if (invite.propertyIds != null && invite.propertyIds!.isNotEmpty) {
        for (var propertyId in invite.propertyIds!) {
          await propertyRepository.assignUserToProperty(
            propertyId: propertyId,
            userId: userId,
            role: invite.role,
          );
        }
      }

      // Accept the invite
      await repository.acceptInvite(inviteId, userId);

      // Send notifications
      await _sendAcceptNotifications(invite, userId);

      return Response.ok(
        jsonEncode({
          'message': 'Invite accepted successfully. You have been assigned to the properties.',
          'invite': invite.toMap(),
        }),
      );
    } catch (e, stack) {
      print('Accept invite error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /invites/<id>/decline
  Future<Response> declineInvite(Request request) async {
    try {
      final inviteId = request.params['id'];

      if (inviteId == null) return badRequest('Invite ID is required');

      final invite = await repository.getInviteById(inviteId);

      if (invite.status != 'Pending') {
        return Response(400, body: jsonEncode({'message': 'This invite has already been processed'}));
      }

      await repository.declineInvite(inviteId);

      return Response.ok(jsonEncode({'message': 'Invite declined successfully'}));
    } catch (e, stack) {
      print('Decline invite error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // HELPER
  Future<List<Map<String, dynamic>>> _enrichInvites(List<InviteModel> invites) async {
    final enriched = <Map<String, dynamic>>[];

    for (var invite in invites) {
      final inviter = await userRepository.getUserById(invite.inviterId);

      List<PropertyModel> properties = [];
      if (invite.propertyIds != null) {
        for (var pid in invite.propertyIds!) {
          final prop = await propertyRepository.getPropertyById(pid);
          if (prop.id.isNotEmpty) {
            properties.add(prop);
          }
        }
      }

      enriched.add({
        ...invite.toMap(),
        'inviter': {
          'id': inviter.id,
          'fullName': inviter.fullName,
          'role': inviter.role,
          'profilePhotoUrl': inviter.profilePhotoUrl,
          'phone': inviter.phone,
          'email': inviter.email,
        },
        'properties': properties.map((e) => e.toMap()).toList(),
        'isExpired': invite.isExpired,
      });
    }

    return enriched;
  }

  Future<void> _sendAcceptNotifications(InviteModel invite, String newUserId) async {
    // Notify Invitee
    await notificationRepository.create(
      NotificationModel(
        userId: newUserId,
        type: 'invite_accepted',
        title: 'Invite Accepted',
        body: 'You have successfully joined the properties as ${invite.role}.',
        relatedId: invite.id,
        relatedCollection: 'invites',
        createdAt: DateTime.now(),
        id: '',
      ),
    );

    // Notify Inviter
    await notificationRepository.create(
      NotificationModel(
        userId: invite.inviterId,
        type: 'invite_accepted',
        title: 'Invite Accepted',
        body: 'User has accepted your invite as ${invite.role}.',
        relatedId: invite.id,
        relatedCollection: 'invites',
        createdAt: DateTime.now(),
        id: '',
      ),
    );
  }

  Response badRequest(String message) => Response(400, body: jsonEncode({'message': message}));
  Response unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
