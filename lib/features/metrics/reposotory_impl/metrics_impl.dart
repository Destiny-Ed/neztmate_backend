import 'package:neztmate_backend/features/metrics/datasource/metric_remote_datasource.dart';
import 'package:neztmate_backend/features/metrics/repository/metrics_repository.dart';

class MetricsRepositoryImpl implements MetricsRepository {
  final MetricsRemoteDataSource dataSource;
  MetricsRepositoryImpl(this.dataSource);

  @override
  Future<Map<String, dynamic>> getRevenueMetrics({String? partnerId}) =>
      dataSource.getRevenueMetrics(partnerId: partnerId);
}
