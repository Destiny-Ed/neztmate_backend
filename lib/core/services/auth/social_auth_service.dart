// import 'package:dart_firebase_admin/auth.dart';
// import 'package:dart_firebase_admin/dart_firebase_admin.dart';

// class SocialAuthService {
//   final app = FirebaseAdminApp.initializeApp(
//     'neztmate_app_id',
//     // This will obtain authentication information from the environment
//     Credential.fromApplicationDefaultCredentials(),
//   );
//   Future<String> verifyFirebaseToken(String idToken) async {
//     final decoded = await Auth(app).verifyIdToken(idToken);

//     return decoded.uid;
//   }

//   Future<UserRecord> getFirebaseUser(String uid) async {
//     final userRecord = await Auth(app).getUser(uid);

//     return userRecord;
//   }
// }
