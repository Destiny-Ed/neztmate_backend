import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/auth_repository.dart';
import 'package:neztmate_backend/infrastructure/database/firestore/firestore.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirestoreService db;

  AuthRepositoryImpl(this.db);

  CollectionReference get users => db.firestore.collection('users');

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    final snapshot = await users.where('email', WhereFilter.equal, email).limit(1).get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();

    return UserModel(
      id: snapshot.docs.first.id,
      email: data['email'],
      phone: data['phone'],
      fullName: data['full_name'],
      profilePhotoUrl: data['profile_photo_url'],
      role: data['role'],
      verifiedIdentity: data['verified_identity'] ?? false,
      verifiedEmployment: data['verified_employment'] ?? false,
      yearsExperience: data['years_experience'],
      primarySkill: data['primary_skill'],
      rating: (data['rating'] ?? 0).toDouble(),
    );
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final doc = await users.doc(id).get();

    if (!doc.exists) return null;

    final data = doc.data();

    return UserModel(
      id: id,
      email: data!['email'],
      phone: data['phone'],
      fullName: data['full_name'],
      profilePhotoUrl: data['profile_photo_url'],
      role: data['role'],
    );
  }

  @override
  Future<UserModel> createUser(UserModel user, String passwordHash) async {
    await users.doc(user.id).set({
      "email": user.email,
      "phone": user.phone,
      "password_hash": passwordHash,
      "full_name": user.fullName,
      "profile_photo_url": user.profilePhotoUrl,
      "role": user.role,
      "verified_identity": user.verifiedIdentity,
      "verified_employment": user.verifiedEmployment,
      "years_experience": user.yearsExperience,
      "primary_skill": user.primarySkill,
      "rating": user.rating,
      "created_at": DateTime.now(),
    });

    return user;
  }

  @override
  Future<void> saveRefreshToken(String userId, String token) async {
    await db.firestore.collection('refresh_tokens').add({
      "user_id": userId,
      "token": token,
      "created_at": DateTime.now(),
    });
  }
}
