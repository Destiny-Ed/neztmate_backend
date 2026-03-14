class UserStats {
  final int totalProperties;
  final double totalRevenue; // in NGN or your currency
  final int totalTenants;
  final int submittedTasks;
  final int maintenanceRequests;
  final double totalWithdrawn;

  UserStats({
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
