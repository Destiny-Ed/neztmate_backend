import 'package:neztmate_backend/features/auth_user/datasources/user_remote_datasource.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_stats_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource dataSource;

  UserRepositoryImpl(this.dataSource);

  @override
  Future<User> getUserById(String id) async {
    return await dataSource.getUserById(id);
  }

  @override
  Future<User> getUserByEmail(String email) async {
    return await dataSource.getUserByEmail(email);
  }

  @override
  Future<User> createUser(User user) async {
    return await dataSource.createUser(user);
  }

  @override
  Future<void> updateUser(User user) async {
    await dataSource.updateUser(user);
  }

  @override
  Future<void> deleteUser(String id) async {
    await dataSource.deleteUser(id);
  }

  @override
  Future<UserStats> getUserStats(String userId, String role) {
    // TODO: implement getUserStats
    throw UnimplementedError();
  }

  // @override
  // Future<UserStats> getUserStats(String userId, String role) async {
  //   int totalProperties = 0;
  //   double totalRevenue = 0.0;
  //   int totalTenants = 0;
  //   int submittedTasks = 0;
  //   int maintenanceRequests = 0;
  //   double totalWithdrawn = 0.0;

  //   // Landowner / Manager stats
  //   if (role == 'landowner' || role == 'manager') {
  //     //  Total properties owned/managed
  //     final propertiesSnap = await firestore
  //         .collection('properties')
  //         .where(role == 'landowner' ? 'landownerId' : 'managerId', isEqualTo: userId)
  //         .get();
  //     totalProperties = propertiesSnap.size;

  //     // Total revenue (successful rent payments)
  //     final paymentsSnap = await firestore
  //         .collection('payments')
  //         .where('payerId', isEqualTo: userId) // or filter by lease → landowner
  //         .where('status', isEqualTo: 'Paid')
  //         .get();

  //     for (var doc in paymentsSnap.docs) {
  //       final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
  //       totalRevenue += amount;
  //     }

  //     //  Total active tenants
  //     final leasesSnap = await firestore
  //         .collection('leases')
  //         .where('landownerId', isEqualTo: userId)
  //         .where('status', isEqualTo: 'Active')
  //         .get();
  //     totalTenants = leasesSnap.size;

  //     // Maintenance requests (all properties)
  //     final requestsSnap = await firestore
  //         .collection('maintenance_requests')
  //         .where('managerId', isEqualTo: userId) // or match via unit/property
  //         .get();
  //     maintenanceRequests = requestsSnap.size;

  //     // Submitted tasks (as manager/artisan)
  //     final tasksSnap = await firestore.collection('tasks').where('managerId', isEqualTo: userId).get();
  //     submittedTasks = tasksSnap.size;

  //     // Total withdrawn (you need a withdrawals collection)
  //     final withdrawalsSnap = await firestore
  //         .collection('withdrawals')
  //         .where('userId', isEqualTo: userId)
  //         .where('status', isEqualTo: 'Completed')
  //         .get();

  //     for (var doc in withdrawalsSnap.docs) {
  //       totalWithdrawn += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
  //     }
  //   }
  //   // Tenant stats (different view)
  //   else if (role == 'Tenant') {
  //     // Tenant sees their own requests/tasks
  //     final requestsSnap = await firestore
  //         .collection('maintenance_requests')
  //         .where('tenantId', isEqualTo: userId)
  //         .get();
  //     maintenanceRequests = requestsSnap.size;

  //     // Tasks assigned to them (if they are artisan too)
  //     final tasksSnap = await firestore.collection('tasks').where('artisanId', isEqualTo: userId).get();
  //     submittedTasks = tasksSnap.size;

  //     // Tenant doesn't see revenue/withdrawn/total properties
  //   }
  //   // Artisan stats
  //   else if (role == 'Artisan') {
  //     final tasksSnap = await firestore.collection('tasks').where('artisanId', isEqualTo: userId).get();
  //     submittedTasks = tasksSnap.size;
  //   }

  //   return UserStats(
  //     totalProperties: totalProperties,
  //     totalRevenue: totalRevenue,
  //     totalTenants: totalTenants,
  //     submittedTasks: submittedTasks,
  //     maintenanceRequests: maintenanceRequests,
  //     totalWithdrawn: totalWithdrawn,
  //   );
  // }
}
