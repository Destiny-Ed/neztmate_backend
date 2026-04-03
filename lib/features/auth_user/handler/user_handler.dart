import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:shelf_router/shelf_router.dart';

class UserHandler {
  final UserRepository userRepository;

  UserHandler(this.userRepository);

  /// GET /users/me
  Future<Response> getCurrentUser(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return unauthorized('Missing authentication');
      }

      final user = await userRepository.getUserById(userId);

      final safeUser = _safeUserMap(user);

      return Response.ok(jsonEncode({'user': safeUser}), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get current user error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch profile'}));
    }
  }

  /// GET /users/<id>
  Future<Response> getUserById(Request request) async {
    try {
      final authenticatedUserId = request.context['userId'] as String?;
      if (authenticatedUserId == null) {
        return unauthorized('Missing authentication');
      }

      final requestedUserId = request.params['id'];
      print("requestedUserId: $requestedUserId");
      if (requestedUserId == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'Missing user ID in path'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userRole = request.context['role'] as String?;
      print(
        'Authenticated user ID: $authenticatedUserId, Role: $userRole, Requested user ID: $requestedUserId',
      );
      final isAdmin = userRole == 'manager' || userRole == 'landowner';
      final isSelf = requestedUserId == authenticatedUserId;

      if (!isSelf && !isAdmin) {
        return Response(
          403,
          body: jsonEncode({'message': 'Forbidden - you can only view your own profile'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final user = await userRepository.getUserById(requestedUserId);

      final safeUser = _safeUserMap(user);

      // Optional: hide sensitive fields for non-self
      // if (!isSelf && !isAdmin) {
      //   safeUser.remove('email');
      //   safeUser.remove('phone');
      // }

      return Response.ok(jsonEncode({'user': safeUser}), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get user by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch user details'}));
    }
  }

  /// GET /users/email/{email}   ← new endpoint for email lookup
  Future<Response> getUserByEmail(Request request) async {
    try {
      final authenticatedUserId = request.context['userId'] as String?;
      if (authenticatedUserId == null) {
        return unauthorized('Missing authentication');
      }

      final email = request.params['email'];
      if (email == null || email.isEmpty) {
        return Response(
          400,
          body: jsonEncode({'message': 'Missing or empty email parameter'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userRole = request.context['role'] as String?;
      final isAdmin = userRole == 'manager' || userRole == 'landowner';

      // Only admins should be able to lookup by email (privacy)
      if (!isAdmin) {
        return Response(
          403,
          body: jsonEncode({'message': 'Forbidden - only managers or landowners can search by email'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final user = await userRepository.getUserByEmail(email);
      final safeUser = _safeUserMap(user);

      // Admins see full data (you can restrict more if needed)
      return Response.ok(jsonEncode({'user': safeUser}), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get user by email error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch user by email'}));
    }
  }

  /// PATCH /users/me
  Future<Response> updateCurrentUser(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return unauthorized('Missing authentication');
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final user = await userRepository.getUserById(userId);

      // Allowed fields (safe copyWith)
      final updatedUser = user.copyWith(
        fullName: body['fullName'] as String?,
        phone: body['phone'] as String?,
        profilePhotoUrl: body['profilePhotoUrl'] as String?,
        yearsExperience: body['yearsExperience'] as int?,
        primarySkill: body['primarySkill'] as String?,
        // Add more allowed fields if needed
      );

      await userRepository.updateUser(updatedUser);

      return Response.ok(
        jsonEncode({
          'message': 'Profile updated successfully',
          'user': {
            'id': updatedUser.id,
            'fullName': updatedUser.fullName,
            'phone': updatedUser.phone,
            'profilePhotoUrl': updatedUser.profilePhotoUrl,
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Update user error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update profile'}));
    }
  }

  /// DELETE /users/me
  Future<Response> deleteCurrentUser(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return unauthorized('Missing authentication');
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body['confirm'] != true) {
        return Response(
          400,
          body: jsonEncode({'message': 'Confirmation required. Send {"confirm": true}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await userRepository.deleteUser(userId);

      return Response.ok(
        jsonEncode({'message': 'Account deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Delete user error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete account'}));
    }
  }

  /// GET /users/stats - Get dashboard statistics for the current user
  Future<Response> getUserStats(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role == null) {
        return unauthorized('Missing authentication');
      }
      print("The main role ::: $role");

      final stats = await userRepository.getUserStats(userId, role);

      return Response.ok(
        jsonEncode({'stats': stats.toJson(), 'message': 'User statistics retrieved successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e) {
      print('Get user stats error app: $e');

      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get user stats error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch statistics'}));
    }
  }

  // Helpers
  Map<String, dynamic> _safeUserMap(User user) => {
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
}
