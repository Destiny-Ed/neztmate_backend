import 'package:bcrypt/bcrypt.dart';

class PasswordService {
  String hash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Returns false if [hash] is null/empty/invalid instead of throwing.
  bool verify(String password, String? hash) {
    if (hash == null || hash.trim().isEmpty) return false;
    // bcrypt hashes are typically 60 chars and start with $2
    if (hash.length < 28 || !hash.startsWith(r'$2')) return false;
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      return false;
    }
  }
}
