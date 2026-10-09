import 'dart:convert';

import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:shelf/shelf.dart';

/// Result of a profile-completion check.
class ProfileCompletionResult {
  final bool isComplete;
  final double progress; // 0.0 – 1.0
  final List<String> missingFields;
  final String role;

  const ProfileCompletionResult({
    required this.isComplete,
    required this.progress,
    required this.missingFields,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'isComplete': isComplete,
        'progress': progress,
        'missingFields': missingFields,
        'role': role,
      };
}

/// Shared profile-completion rules for tenants, landowners, managers, artisans.
///
///   - all roles: fullName, email, phone, address, profilePhotoUrl
///   - artisan only: primarySkill
class ProfileCompletionValidator {
  ProfileCompletionValidator._();

  static const code = 'PROFILE_NOT_COMPLETE';
  static const action = 'complete_profile';

  static const List<String> baseRequiredFields = [
    'fullName',
    'email',
    'phone',
    'address',
    'profilePhotoUrl',
  ];

  static const List<String> artisanRequiredFields = [
    'primarySkill',
  ];

  /// Required field keys for [role] (case-insensitive role string).
  static List<String> requiredFieldsForRole(String role) {
    final r = role.toLowerCase().trim();
    if (r == 'artisan') {
      return [...baseRequiredFields, ...artisanRequiredFields];
    }
    return List.unmodifiable(baseRequiredFields);
  }

  /// Evaluate completion for [user]. Does not throw.
  static ProfileCompletionResult evaluate(User user) {
    final role = user.role.toLowerCase().trim();
    final required = requiredFieldsForRole(role);
    final missing = <String>[];

    for (final field in required) {
      if (!_hasValue(user, field)) {
        missing.add(field);
      }
    }

    final total = required.length;
    final completed = total - missing.length;
    final progress = total == 0 ? 1.0 : completed / total;

    return ProfileCompletionResult(
      isComplete: missing.isEmpty,
      progress: progress,
      missingFields: missing,
      role: role,
    );
  }

  static bool isComplete(User user) => evaluate(user).isComplete;

  /// Ready-to-return 403 when profile is incomplete; `null` when complete.
  ///
  /// Usage in handlers:
  /// ```dart
  /// final blocked = ProfileCompletionValidator.ensureComplete(user);
  /// if (blocked != null) return blocked;
  /// ```
  static Response? ensureComplete(User user, {String? message}) {
    final result = evaluate(user);
    if (result.isComplete) return null;
    return incompleteResponse(user, result: result, message: message);
  }

  /// Build the standard PROFILE_NOT_COMPLETE response body.
  static Response incompleteResponse(
    User user, {
    ProfileCompletionResult? result,
    String? message,
  }) {
    final r = result ?? evaluate(user);
    final friendly = message ??
        'Complete your profile to continue. Missing: ${r.missingFields.join(', ')}.';

    return Response(
      403,
      body: jsonEncode({
        'message': friendly,
        'code': code,
        'action': action,
        'missingFields': r.missingFields,
        'progress': r.progress,
        'role': r.role,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static bool _hasValue(User user, String field) {
    switch (field) {
      case 'fullName':
        return user.fullName.trim().isNotEmpty;
      case 'email':
        return user.email.trim().isNotEmpty;
      case 'phone':
        return (user.phone ?? '').trim().isNotEmpty;
      case 'address':
        return (user.address ?? '').trim().isNotEmpty;
      case 'profilePhotoUrl':
        return (user.profilePhotoUrl ?? '').trim().isNotEmpty;
      case 'primarySkill':
        return (user.primarySkill ?? '').trim().isNotEmpty;
      case 'bio':
        return (user.bio ?? '').trim().isNotEmpty;
      default:
        return true;
    }
  }
}
