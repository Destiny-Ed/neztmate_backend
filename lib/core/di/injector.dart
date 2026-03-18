import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/core/services/database/firebase/firebase.dart';
import 'package:neztmate_backend/features/auth_user/datasources/firestore/firestore_user_datasource.dart';
import 'package:neztmate_backend/features/history/datasource/firestore/history_firestore_datasource.dart';
import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/handler/history_handler.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/history/repository_impl/history_repo_impl.dart';
import 'package:neztmate_backend/features/leases/datasource/firestore/firestore_lease_datasource.dart';
import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/leases/repository_impl/lease_repo_impl.dart';
import 'package:neztmate_backend/features/properties/datasources/firestore/firestore_property_datasource.dart';
import 'package:neztmate_backend/features/auth_user/datasources/user_remote_datasource.dart';
import 'package:neztmate_backend/features/auth_user/handler/auth_handler.dart';
import 'package:neztmate_backend/features/auth_user/handler/user_handler.dart';
import 'package:neztmate_backend/features/auth_user/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/auth_user/repository_impl/firestore/auth_repository_impl.dart';
import 'package:neztmate_backend/features/auth_user/repository_impl/firestore/user_repository_impl.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/handler/property_handler.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/properties/repository_impl/property_impl.dart';
import 'package:neztmate_backend/features/units/datasource/firestore/unit_firestore_datasource.dart';
import 'package:neztmate_backend/features/units/datasource/unit_remote_datasource.dart';
import 'package:neztmate_backend/features/units/handler/unit_handler.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:neztmate_backend/features/units/repository_impl/unit_repo_impl.dart';

final injector = GetIt.instance;

Future<void> setupDependencies({bool usePostgres = false, required String jwtSecret}) async {
  // 1. Database / Firebase setup
  if (usePostgres) {
    // final db = PostgresService();
    // await db.connect();
    // injector.registerLazySingleton<PostgresService>(() => db);
    // injector.registerLazySingleton<UserRemoteDataSource>(
    //   () => PostgresUserDataSource(db),
    // );
    throw UnimplementedError("Postgres support not fully implemented yet");
  } else {
    final firebaseService = FirebaseService();
    await firebaseService.init();

    injector.registerLazySingleton<FirebaseService>(() => firebaseService);
    injector.registerLazySingleton<Firestore>(() => firebaseService.firestore);
    injector.registerLazySingleton<Auth>(() => firebaseService.auth);
  }

  // 2. Core services
  injector.registerLazySingleton<PasswordService>(() => PasswordService());
  injector.registerLazySingleton<JwtService>(() => JwtService(jwtSecret));

  // 3. Data sources & repositories
  ///user
  injector.registerLazySingleton<UserRemoteDataSource>(() => FirestoreUserDataSource(injector<Firestore>()));
  injector.registerLazySingleton<UserRepository>(() => UserRepositoryImpl(injector<UserRemoteDataSource>()));
  injector.registerLazySingleton<UserHandler>(() => UserHandler(injector<UserRepository>()));

  //properties
  injector.registerLazySingleton<PropertyRemoteDataSource>(
    () => FirestorePropertyDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<PropertyRepository>(() => PropertyRepositoryImpl(injector()));
  injector.registerLazySingleton<PropertyHandler>(() => PropertyHandler(injector()));

  //units
  injector.registerLazySingleton<UnitRemoteDataSource>(() => FirestoreUnitDataSource(injector<Firestore>()));
  injector.registerLazySingleton<UnitRepository>(
    () => UnitRepositoryImpl(
      injector<UnitRemoteDataSource>(),
      injector<PropertyRemoteDataSource>(),
      injector<HistoryRepository>(),
      injector<UserRepository>(),
      injector<LeaseRepository>(),
    ),
  );
  injector.registerLazySingleton<UnitHandler>(() => UnitHandler(injector<UnitRepository>()));

  //history
  injector.registerLazySingleton<HistoryRemoteDataSource>(
    () => FirestoreHistoryDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<HistoryRepository>(
    () => HistoryRepositoryImpl(injector<HistoryRemoteDataSource>()),
  );
  injector.registerLazySingleton<HistoryHandler>(() => HistoryHandler(injector<HistoryRepository>()));

  //auth
  injector.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      userRepository: injector<UserRepository>(),
      firebaseAuth: injector<Auth>(),
      passwordService: injector<PasswordService>(),
      firestore: injector<Firestore>(),
    ),
  );

  injector.registerLazySingleton<AuthHandler>(
    () => AuthHandler(
      injector<AuthRepository>(),
      injector<PasswordService>(),
      injector<JwtService>(),
      injector<UserRepository>(),
    ),
  );

  //Leases
  injector.registerLazySingleton<LeaseRemoteDataSource>(
    () => FirestoreLeaseDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<LeaseRepository>(
    () => LeaseRepositoryImpl(injector<LeaseRemoteDataSource>()),
  );
  injector.registerLazySingleton<LeaseHandler>(() => LeaseHandler(injector<LeaseRepository>()));
}
