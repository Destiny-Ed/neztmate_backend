import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/auth_user/datasources/user_remote_datasource.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

class FirestoreUserDataSource implements UserRemoteDataSource {
  final Firestore firestore;

  FirestoreUserDataSource(this.firestore);

  CollectionReference get _users => firestore.collection('users');

  @override
  Future<User?> getUserById(String id) async {
    final doc = await _users.doc(id).get();
    if (!doc.exists) {
      return null;
    }
    final data = doc.data() as Map<String, dynamic>;
    return User.fromMap(data);
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    final snapshot = await _users.where('email', WhereFilter.equal, email).limit(1).get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    return User.fromMap(data);
  }

  @override
  Future<User> createUser(User user) async {
    await _users.doc(user.id).set(user.toMap());
    return user;
  }

  @override
  Future<void> updateUser(User user) async {
    await _users.doc(user.id).update(user.toMap());
  }

  @override
  Future<void> deleteUser(String id) async {
    await _users.doc(id).delete();
  }
}
