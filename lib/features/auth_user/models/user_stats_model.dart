class UserStatsModel {
  final int totalProperties;
  final double totalRevenue;
  final int totalTenants;
  final int submittedTasks;
  final int maintenanceRequests;
  final double totalWithdrawn;

  UserStatsModel({
    required this.totalProperties,
    required this.totalRevenue,
    required this.totalTenants,
    required this.submittedTasks,
    required this.maintenanceRequests,
    required this.totalWithdrawn,
  });

  Map<String, dynamic> toJson() => {
    'totalProperties': totalProperties,
    'totalRevenue': totalRevenue,
    'totalTenants': totalTenants,
    'submittedTasks': submittedTasks,
    'maintenanceRequests': maintenanceRequests,
    'totalWithdrawn': totalWithdrawn,
  };
}
