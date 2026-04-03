import 'package:dart_firebase_admin/firestore.dart';
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
    final doc = await _users.doc(id).get();
    print('getUserById: Fetched document for ID $id: ${doc.data()}');
    if (!doc.exists) {
      throw NotFoundException('User', id);
    }
    final data = doc.data() as Map<String, dynamic>;
    return User.fromMap(data);
  }

  @override
  Future<User> getUserByEmail(String email) async {
    final snapshot = await _users.where('email', WhereFilter.equal, email).limit(1).get();

    if (snapshot.docs.isEmpty) {
      throw NotFoundException('User with email $email');
    }
    final doc = snapshot.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    return User.fromMap(data);
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
    int totalProperties = 0;
    double totalRevenue = 0.0;
    int totalTenants = 0;
    int submittedTasks = 0;
    int maintenanceRequests = 0;
    double totalWithdrawn = 0.0;

    try {
      print("The main role ::: $role");
      // Landowner / Manager stats
      if (role == 'landowner' || role == 'manager') {
        final propertyField = role == 'landowner' ? 'landownerId' : 'managerId';

        // 1. Total properties
        final propertiesSnap = await firestore
            .collection('properties')
            .where(propertyField, WhereFilter.equal, userId)
            .get();
        totalProperties = propertiesSnap.docs.length;

        // 2. Total revenue from paid payments
        final paymentsSnap = await firestore
            .collection('payments')
            .where('status', WhereFilter.equal, 'Paid')
            .get();

        for (var doc in paymentsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          totalRevenue += amount;
        }

        // 3. Total active tenants
        final leasesSnap = await firestore
            .collection('leases')
            .where('landownerId', WhereFilter.equal, userId)
            .where('status', WhereFilter.equal, 'Active')
            .get();
        totalTenants = leasesSnap.docs.length;

        // 4. Maintenance requests
        final requestsSnap = await firestore
            .collection('maintenance_requests')
            .where('managerId', WhereFilter.equal, userId)
            .get();
        maintenanceRequests = requestsSnap.docs.length;

        // 5. Submitted tasks (as manager)
        final tasksSnap = await firestore
            .collection('tasks')
            .where('managerId', WhereFilter.equal, userId)
            .get();
        submittedTasks = tasksSnap.docs.length;

        // 6. Total withdrawn
        final withdrawalsSnap = await firestore
            .collection('withdrawals')
            .where('userId', WhereFilter.equal, userId)
            .where('status', WhereFilter.equal, 'Completed')
            .get();

        for (var doc in withdrawalsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalWithdrawn += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      // Tenant stats
      else if (role == 'tenant') {
        final requestsSnap = await firestore
            .collection('maintenance_requests')
            .where('tenantId', WhereFilter.equal, userId)
            .get();
        maintenanceRequests = requestsSnap.docs.length;

        final tasksSnap = await firestore
            .collection('tasks')
            .where('artisanId', WhereFilter.equal, userId)
            .get();
        submittedTasks = tasksSnap.docs.length;
      }
      // Artisan stats
      else if (role == 'artisan') {
        final tasksSnap = await firestore
            .collection('tasks')
            .where('artisanId', WhereFilter.equal, userId)
            .get();
        submittedTasks = tasksSnap.docs.length;
      }

      return UserStatsModel(
        totalProperties: totalProperties,
        totalRevenue: totalRevenue,
        totalTenants: totalTenants,
        submittedTasks: submittedTasks,
        maintenanceRequests: maintenanceRequests,
        totalWithdrawn: totalWithdrawn,
      );
    } catch (e, stack) {
      print('getUserStats error: $e\n$stack');
      rethrow;
    }
  }
}
