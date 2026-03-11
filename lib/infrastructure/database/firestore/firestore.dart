import 'dart:io';

import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';

class FirestoreService {
  late FirebaseAdminApp app;
  late Firestore firestore;

  Future<void> init() async {
    app = FirebaseAdminApp.initializeApp(
      '<your project name>',
      // Log-in using the newly downloaded file.
      Credential.fromServiceAccount(File('<path to your service-account.json file>')),
    );

    firestore = Firestore(app);
  }
}
