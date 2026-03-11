import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/user_repository.dart';
import 'package:neztmate_backend/infrastructure/database/firestore/firestore.dart';

class UserRepositoryImpl implements UserRepository {
  final FirestoreService db;

  UserRepositoryImpl(this.db);

  CollectionReference get users => db.firestore.collection('users');

  @override
  Future<UserModel?> getUser(String id) async {
    final doc = await users.doc(id).get();

    if (!doc.exists) return null;

    final data = doc.data();

    return UserModel(
      id: id,
      email: data!['email'],
      phone: data['phone'],
      fullName: data['full_name'],
      role: data['role'],
    );
  }

  @override
  Future<List<UserModel>> getUsers() async {
    final snapshot = await users.get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return UserModel(
        id: doc.id,
        email: data['email'],
        phone: data['phone'],
        fullName: data['full_name'],
        role: data['role'],
      );
    }).toList();
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await users.doc(user.id).update({
      "full_name": user.fullName,
      "phone": user.phone,
      "profile_photo_url": user.profilePhotoUrl,
    });
  }

  @override
  Future<void> deleteUser(String id) async {
    await users.doc(id).delete();
  }
}
