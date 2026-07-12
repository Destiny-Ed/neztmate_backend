import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/cache/app_cache.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/auth_user/datasources/user_remote_datasource.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_stats_model.dart';

class FirestoreUserDataSource implements UserRemoteDataSource {
  final Firestore firestore;

  FirestoreUserDataSource(this.firestore);

  CollectionReference get _users => firestore.collection('users');

  @override
  Future<User> getUserById(String id) async {
    final cacheKey = 'user_$id';

    final cached = AppCache().get<User>(cacheKey);
    if (cached != null) return cached;

    final doc = await _users.doc(id).get();
    if (!doc.exists) {
      throw NotFoundException('User', id);
    }
    final data = doc.data() as Map<String, dynamic>;

    final user = User.fromMap(data);
    AppCache().set(cacheKey, user, ttl: const Duration(minutes: 2));

    return user;
  }

  @override
  Future<User> getUserByEmail(String email) async {
    final cacheKey = 'user_$email';

    final cached = AppCache().get<User>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _users.where('email', WhereFilter.equal, email).limit(1).get();

    if (snapshot.docs.isEmpty) {
      throw NotFoundException('User with email $email');
    }
    final doc = snapshot.docs.first;
    final data = doc.data() as Map<String, dynamic>;

    final user = User.fromMap(data);
    AppCache().set(cacheKey, user, ttl: const Duration(minutes: 2));

    return user;
  }

  @override
  Future<User> createUser(User user) async {
    final snapshot = await _users.where('email', WhereFilter.equal, user.email).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      throw EmailAlreadyExistsException(user.email);
    }
    await _users.doc(user.id).set(user.toMap());
    return user;
  }

  @override
  Future<void> updateUser(User user) async {
    await _users.doc(user.id).update(user.toMap());
  }

  @override
  Future<void> deleteUser(String id) async {
    await _users.doc(id).delete();
  }

  @override
  Future<UserStatsModel> getUserStats(String userId, String role) async {
    try {
      final cacheKey = 'user_stats_$userId';

      final cached = AppCache().get<UserStatsModel>(cacheKey);
      if (cached != null) return cached;

      int totalProperties = 0;
      double totalRevenue = 0.0;
      int totalTenants = 0;
      int submittedTasks = 0;
      int completedTasks = 0;
      int maintenanceRequests = 0;
      double totalWithdrawn = 0.0;
      double totalCommissionEarned = 0.0; // For managers
      int activeTasks = 0;

      // LANDOWNER / MANAGER STATS
      if (role == 'landowner' || role == 'manager') {
        final propertyField = role == 'landowner' ? 'landownerId' : 'managerId';

        // 1. Total Properties
        final propertiesSnap = await firestore
            .collection('properties')
            .where(propertyField, WhereFilter.equal, userId)
            .get();
        totalProperties = propertiesSnap.docs.length;

        // 2. Total Revenue (from paid payments)
        final paymentsSnap = await firestore
            .collection('payments')
            .where('status', WhereFilter.equal, 'Paid')
            .get();

        for (var doc in paymentsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalRevenue += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // 3. Total Active Tenants
        final leasesSnap = await firestore
            .collection('leases')
            .where('landownerId', WhereFilter.equal, userId)
            .where('status', WhereFilter.equal, 'Active')
            .get();
        totalTenants = leasesSnap.docs.length;

        // 4. Maintenance Requests
        final requestsSnap = await firestore
            .collection('maintenance_requests')
            .where('managerId', WhereFilter.equal, userId)
            .get();
        maintenanceRequests = requestsSnap.docs.length;

        // 5. Tasks (Submitted & Completed)
        final tasksSnap = await firestore
            .collection('tasks')
            .where('managerId', WhereFilter.equal, userId)
            .get();
        submittedTasks = tasksSnap.docs.length;

        for (var doc in tasksSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'Completed') completedTasks++;
          if (data['status'] == 'InProgress' || data['status'] == 'Accepted') activeTasks++;
        }

        // 6. Total Withdrawn
        final withdrawalsSnap = await firestore
            .collection('withdrawals')
            .where('userId', WhereFilter.equal, userId)
            .where('status', WhereFilter.equal, 'Completed')
            .get();

        for (var doc in withdrawalsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalWithdrawn += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // 7. Manager Commission (NEW)
        final commissionsSnap = await firestore
            .collection('manager_commissions')
            .where('managerId', WhereFilter.equal, userId)
            .get();

        for (var doc in commissionsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalCommissionEarned += (data['commissionAmount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      // TENANT STATS
      else if (role == 'tenant') {
        final requestsSnap = await firestore
            .collection('maintenance_requests')
            .where('tenantId', WhereFilter.equal, userId)
            .get();
        maintenanceRequests = requestsSnap.docs.length;

        final tasksSnap = await firestore
            .collection('tasks')
            .where('tenantId', WhereFilter.equal, userId) // if applicable
            .get();
        submittedTasks = tasksSnap.docs.length;
      }
      // ARTISAN STATS
      else if (role == 'artisan') {
        final tasksSnap = await firestore
            .collection('tasks')
            .where('artisanId', WhereFilter.equal, userId)
            .get();

        submittedTasks = tasksSnap.docs.length;

        for (var doc in tasksSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'Completed') completedTasks++;
          if (data['status'] == 'InProgress' || data['status'] == 'Accepted') activeTasks++;
        }
      }

      final stats = UserStatsModel(
        totalProperties: totalProperties,
        totalRevenue: totalRevenue,
        totalTenants: totalTenants,
        submittedTasks: submittedTasks,
        completedTasks: completedTasks,
        activeTasks: activeTasks,
        maintenanceRequests: maintenanceRequests,
        totalWithdrawn: totalWithdrawn,
        totalCommissionEarned: totalCommissionEarned,
      );

      AppCache().set(cacheKey, stats, ttl: const Duration(minutes: 2));

      return stats;
    } catch (e, stack) {
      print('getUserStats error: $e\n$stack');
      rethrow;
    }
  }

  @override
  Future<User?> getUserByVerificationId(String verificationId) async {
    final snap = await _users.where('verificationId', WhereFilter.equal, verificationId).limit(1).get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return User.fromMap(doc.data() as Map<String, dynamic>);
  }
}
