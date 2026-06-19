import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

class ArtisanWithStats {
  final User artisan;
  final int activeTasksCount;
  final int completedTasksCount;

  ArtisanWithStats({required this.artisan, this.activeTasksCount = 0, this.completedTasksCount = 0});

  Map<String, dynamic> toMap() {
    return {
      'artisan': {
        'id': artisan.id,
        'fullName': artisan.fullName,
        'email': artisan.email,
        'phone': artisan.phone,
        'profilePhotoUrl': artisan.profilePhotoUrl,
        'role': artisan.role,
        'primarySkill': artisan.primarySkill,
        'rating': artisan.rating,
      },
      'activeTasksCount': activeTasksCount,
      'completedTasksCount': completedTasksCount,
    };
  }
}
