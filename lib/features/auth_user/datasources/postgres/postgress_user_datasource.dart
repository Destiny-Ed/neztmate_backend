// // lib/features/auth/data/datasources/postgres_user_datasource.dart
// import 'package:postgres/postgres.dart';

// class PostgresUserDataSource implements UserRemoteDataSource {
//   final PostgreSQLConnection connection;

//   PostgresUserDataSource(this.connection);

//   @override
//   Future<UserModel> getUserById(String uid) async {
//     final result = await connection.query(
//       'SELECT * FROM users WHERE id = @id',
//       substitutionValues: {'id': uid},
//     );
//     if (result.isEmpty) throw Exception('User not found');
//     return UserModel.fromPostgresRow(result.first);
//   }

//   // Implement others using INSERT, UPDATE, etc.
// }
