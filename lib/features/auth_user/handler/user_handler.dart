import 'dart:convert';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class UserHandler {
  final UserRepository userRepository;

  UserHandler(this.userRepository);

  /// GET /users/me  → get current authenticated user's profile
  Future<Response> getCurrentUser(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final user = await userRepository.getUserById(userId);
      if (user == null) {
        return Response(404, body: jsonEncode({'message': 'User not found'}));
      }

      // Never return sensitive fields like passwordHash
      final safeUser = {
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'role': user.role,
        'phone': user.phone,
        'profilePhotoUrl': user.profilePhotoUrl,
        'verifiedIdentity': user.verifiedIdentity,
        'verifiedEmployment': user.verifiedEmployment,
        'yearsExperience': user.yearsExperience,
        'primarySkill': user.primarySkill,
        'rating': user.rating,
        'createdAt': user.createdAt.toIso8601String(),
        'lastLogin': user.lastLogin.toIso8601String(),
        'authProvider': user.authProvider,
        'country': user.country,
        'platform': user.platform,
      };

      return Response.ok(jsonEncode({'user': safeUser}), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('Get current user error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch profile'}));
    }
  }

  Future<Response> getUserById(Request request) async {
    try {
      final authenticatedUserId = request.context['userId'] as String?;
      if (authenticatedUserId == null) {
        return Response(
          401,
          body: jsonEncode({'message': 'Unauthorized - missing authentication'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      //  Get the requested user ID from path parameter (:id)
      final requestedUserId = request.params['id'];
      if (requestedUserId == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'Missing user ID in path'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Authorization check – only allow self or admin
      final userRole = request.context['role'] as String?;
      final isAdmin = userRole == 'Manager' || userRole == 'Landowner'; // adjust roles as needed
      final isSelf = requestedUserId == authenticatedUserId;

      if (!isSelf && !isAdmin) {
        return Response(
          403,
          body: jsonEncode({'message': 'Forbidden - you can only view your own profile'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final user = await userRepository.getUserById(requestedUserId);
      if (user == null) {
        return Response(
          404,
          body: jsonEncode({'message': 'User not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final safeUser = {
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'role': user.role,
        'phone': user.phone,
        'profilePhotoUrl': user.profilePhotoUrl,
        'verifiedIdentity': user.verifiedIdentity,
        'verifiedEmployment': user.verifiedEmployment,
        'yearsExperience': user.yearsExperience,
        'primarySkill': user.primarySkill,
        'rating': user.rating,
        'createdAt': user.createdAt.toIso8601String(),
        'lastLogin': user.lastLogin.toIso8601String(),
        'authProvider': user.authProvider,
        'country': user.country,
        'platform': user.platform,
      };

      // Optional: hide email/phone for non-self users
      // if (!isSelf && !isAdmin) {
      //   safeUser.remove('email');
      //   safeUser.remove('phone');
      // }

      return Response.ok(jsonEncode({'user': safeUser}), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('Get user by id error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to fetch user details'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// PATCH /users/me  → update current user's profile
  Future<Response> updateCurrentUser(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final Map<String, dynamic> body = jsonDecode(await request.readAsString());
      final user = await userRepository.getUserById(userId);
      if (user == null) {
        return Response(404, body: jsonEncode({'message': 'User not found'}));
      }

      // Allowed fields to update (never allow password/role change here)
      final updatedFields = <String, dynamic>{};

      if (body.containsKey('fullName')) {
        updatedFields['fullName'] = body['fullName'] as String;
      }
      if (body.containsKey('phone')) {
        updatedFields['phone'] = body['phone'] as String?;
      }
      if (body.containsKey('profilePhotoUrl')) {
        updatedFields['profilePhotoUrl'] = body['profilePhotoUrl'] as String?;
      }
      if (body.containsKey('yearsExperience')) {
        updatedFields['yearsExperience'] = body['yearsExperience'] as int?;
      }
      if (body.containsKey('primarySkill')) {
        updatedFields['primarySkill'] = body['primarySkill'] as String?;
      }

      if (updatedFields.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'No valid fields to update'}));
      }

      // Create updated user object using copyWith
      final updatedUser = user.copyWith(
        fullName: body['fullName'] as String?,
        phone: body['phone'] as String?,
        profilePhotoUrl: body['profilePhotoUrl'] as String?,
        yearsExperience: body['yearsExperience'] as int?,
        primarySkill: body['primarySkill'] as String?,
      );

      await userRepository.updateUser(updatedUser);

      return Response.ok(
        jsonEncode({
          'message': 'Profile updated successfully',
          'user': {'id': updatedUser.id, 'fullName': updatedUser.fullName, 'phone': updatedUser.phone},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Update user error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to update profile'}));
    }
  }

  /// DELETE /users/me  → delete own account (with confirmation)
  Future<Response> deleteCurrentUser(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      // Optional: require body with confirmation
      final body = jsonDecode(await request.readAsString());
      if (body['confirm'] != true) {
        return Response(400, body: jsonEncode({'message': 'Confirmation required. Send {"confirm": true}'}));
      }

      await userRepository.deleteUser(userId);

      return Response.ok(jsonEncode({'message': 'Account deleted successfully'}));
    } catch (e, stack) {
      print('Delete user error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete account'}));
    }
  }
}
