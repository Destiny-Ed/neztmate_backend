import 'dart:convert';
import 'dart:io';
import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:dotenv/dotenv.dart';

class FirebaseService {
  late FirebaseAdminApp app;
  late Firestore firestore;
  late Auth auth;

  bool _isInitialized = false;

  final env = DotEnv()..load();

  final _isLocalTest = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      Credential? credential;

      if (_isLocalTest) {
        final serviceAccountPath =
            Platform.environment['FIREBASE_SERVICE_ACCOUNT_PATH'] ?? env['FIREBASE_SERVICE_ACCOUNT_PATH'];

        if (serviceAccountPath == null) throw 'Firebase service account not found';

        credential = Credential.fromServiceAccount(File(serviceAccountPath));
      } else {
        final serviceAccountJson = Platform.environment['FIREBASE_SERVICE_ACCOUNT_PATH'];

        if (serviceAccountJson == null) throw 'Firebase service account not found';

        final params = jsonDecode(serviceAccountJson) as Map<String, dynamic>;

        credential = Credential.fromServiceAccountParams(
          clientId: params['client_id'],
          privateKey: params['private_key'],
          email: params['client_email'],
        );
      }

      app = FirebaseAdminApp.initializeApp('next-mate', credential);

      firestore = Firestore(app);
      auth = Auth(app);

      _isInitialized = true;
      print('Firebase Admin initialized successfully (project: ${app.projectId})');
    } catch (e, stack) {
      print('Firebase initialization failed: $e');
      print(stack);
      rethrow;
    }
  }

  // Convenience getters
  Firestore get db => firestore;
  Auth get firebaseAuth => auth;
}
