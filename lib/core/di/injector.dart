import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/core/services/database/firebase/firebase.dart';
import 'package:neztmate_backend/features/applications/datasource/application_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/datasource/firestore/firestore_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/handler/application_handler.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:neztmate_backend/features/applications/repository_impl/repository_impl.dart';
import 'package:neztmate_backend/features/auth_user/datasources/firestore/firestore_user_datasource.dart';
import 'package:neztmate_backend/features/community/datasource/firestore/firestore_remote_datasource.dart';
import 'package:neztmate_backend/features/community/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/community/handler/community_handler.dart';
import 'package:neztmate_backend/features/community/repository/community_post_repo.dart';
import 'package:neztmate_backend/features/community/repository_impl/comunity_repo_impl.dart';
import 'package:neztmate_backend/features/history/datasource/firestore/history_firestore_datasource.dart';
import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/handler/history_handler.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/history/repository_impl/history_repo_impl.dart';
import 'package:neztmate_backend/features/invites/datasource/firestore/invite_firestore_datasource.dart';
import 'package:neztmate_backend/features/invites/handler/invite_handler.dart';
import 'package:neztmate_backend/features/invites/invite_repository_impl/invite_repo_impl.dart';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';
import 'package:neztmate_backend/features/leases/datasource/firestore/firestore_lease_datasource.dart';
import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/leases/repository_impl/lease_repo_impl.dart';
import 'package:neztmate_backend/features/maintenance/datasource/firestore/firestore_maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/datasource/maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/handler/maintenance_handler.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:neztmate_backend/features/maintenance/repository_impl/repository_impl.dart';
import 'package:neztmate_backend/features/messages/datasource/firestore/firestore_message_remote_datasource.dart';
import 'package:neztmate_backend/features/messages/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/messages/handler/messages_handler.dart';
import 'package:neztmate_backend/features/messages/repository/message_repo.dart';
import 'package:neztmate_backend/features/messages/repository_impl/messages_repo_impl.dart';
import 'package:neztmate_backend/features/notifications/datasource/firestore/firestore_remote_datasource.dart';
import 'package:neztmate_backend/features/notifications/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/notifications/handler/handler.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/notifications/repository_impl/notification_repo_impl.dart';
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
import 'package:neztmate_backend/features/tasks/datasource/firestore/firestore_task_remote_datasource.dart';
import 'package:neztmate_backend/features/tasks/datasource/task_remote_datasource.dart';
import 'package:neztmate_backend/features/tasks/handler/task_handler.dart';
import 'package:neztmate_backend/features/tasks/repository/task_repo.dart';
import 'package:neztmate_backend/features/tasks/repository_impl/task_repo_impl.dart';
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

  //applications
  injector.registerLazySingleton<ApplicationRemoteDataSource>(
    () => FirestoreApplicationDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<ApplicationRepository>(
    () => ApplicationRepositoryImpl(injector<ApplicationRemoteDataSource>()),
  );
  injector.registerLazySingleton<ApplicationHandler>(
    () => ApplicationHandler(injector<ApplicationRepository>()),
  );

  //maintenance request
  injector.registerLazySingleton<MaintenanceRequestRemoteDataSource>(
    () => FirestoreMaintenanceRequestDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<MaintenanceRequestRepository>(
    () => MaintenanceRequestRepositoryImpl(injector<MaintenanceRequestRemoteDataSource>()),
  );
  injector.registerLazySingleton<MaintenanceRequestHandler>(
    () => MaintenanceRequestHandler(injector<MaintenanceRequestRepository>()),
  );

  //invites
  injector.registerLazySingleton<FirestoreInviteDataSource>(
    () => FirestoreInviteDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<InviteRepositoryImpl>(
    () => InviteRepositoryImpl(injector<FirestoreInviteDataSource>()),
  );
  injector.registerLazySingleton<InviteHandler>(() => InviteHandler(injector<InviteRepositoryImpl>()));

  //Task
  injector.registerLazySingleton<TaskRemoteDataSource>(() => FirestoreTaskDataSource(injector<Firestore>()));

  injector.registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(injector<TaskRemoteDataSource>()));

  injector.registerLazySingleton<TaskHandler>(() => TaskHandler(injector<TaskRepository>()));

  //community
  injector.registerLazySingleton<CommunityRemoteDataSource>(
    () => FirestoreCommunityDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<CommunityRepository>(
    () => CommunityRepositoryImpl(injector<CommunityRemoteDataSource>()),
  );
  injector.registerLazySingleton<CommunityHandler>(() => CommunityHandler(injector<CommunityRepository>()));

  ///messages
  injector.registerLazySingleton<MessageRemoteDataSource>(
    () => FirestoreMessageDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<MessageRepository>(
    () => MessageRepositoryImpl(injector<MessageRemoteDataSource>()),
  );
  injector.registerLazySingleton<MessageHandler>(() => MessageHandler(injector<MessageRepository>()));

  //notifications
  injector.registerLazySingleton<NotificationRemoteDataSource>(
    () => FirestoreNotificationDataSource(injector<Firestore>()),
  );
  injector.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(injector<NotificationRemoteDataSource>()),
  );
  injector.registerLazySingleton<NotificationHandler>(
    () => NotificationHandler(injector<NotificationRepository>()),
  );
}
