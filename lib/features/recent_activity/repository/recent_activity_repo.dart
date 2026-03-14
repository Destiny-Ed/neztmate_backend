import 'package:neztmate_backend/features/recent_activity/models/recent_model.dart';

abstract class RecentActivityRepository {
  Future<RecentActivityModel> createActivity(RecentActivityModel activity);
  Future<List<RecentActivityModel>> getRecentActivitiesByUser(String userId, {int limit = 20});
  Future<void> deleteOldActivities(String userId, {int daysOld = 90}); // optional cleanup
}
