import 'package:get_it/get_it.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/user_repository.dart';
import 'package:neztmate_backend/features/auth/domain/usecases/register_user.dart';
import 'package:neztmate_backend/infrastructure/auth/password_service.dart';
import 'package:neztmate_backend/infrastructure/database/firestore/firestore.dart';

import '../../features/auth/data/repository_impl/firestore/auth_repository_impl.dart';
import '../../features/auth/data/repository_impl/firestore/user_repository_imp.dart';

final injector = GetIt.instance;

void setupDependencies() async {
  // final db = PostgresService();
  // await db.connect();

  // final authRepository = AuthRepositoryImpl(db);
  // final userRepository = UserRepositoryImpl(db);

  final firestoreService = FirestoreService();
  await firestoreService.init();

  final authRepository = AuthRepositoryImpl(firestoreService);
  final userRepository = UserRepositoryImpl(firestoreService);

  injector.registerLazySingleton<AuthRepository>(() => authRepository);
  injector.registerLazySingleton<UserRepository>(() => userRepository);

  injector.registerLazySingleton(() => PasswordService());

  injector.registerFactory(() => RegisterUser(injector(), injector()));
}
