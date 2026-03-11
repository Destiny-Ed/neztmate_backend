import 'package:postgres/postgres.dart';

class PostgresService {
  late final Connection connection;

  Future<void> connect() async {
    connection = await Connection.open(
      Endpoint(host: "localhost", database: "neztmate", username: "postgres", password: "password"),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
  }
}
