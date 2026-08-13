import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  final String secret;

  JwtService(this.secret);

  String generateAccessToken(String userId, String role, {String partnerId = ''}) {
    final jwt = JWT({"sub": userId, "role": role, 'partnerId': partnerId, "type": "access"});

    return jwt.sign(SecretKey(secret), expiresIn: const Duration(hours: 48));
  }

  String generateRefreshToken(String userId) {
    final jwt = JWT({"sub": userId, "type": "refresh"});

    return jwt.sign(SecretKey(secret), expiresIn: const Duration(days: 30));
  }

  JWT verify(String token) {
    return JWT.verify(token, SecretKey(secret));
  }
}
