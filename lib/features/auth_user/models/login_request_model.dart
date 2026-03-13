class LoginRequest {
  final String email;
  final String password;
  final String fcmToken;

  LoginRequest({required this.email, required this.password, required this.fcmToken});

  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return LoginRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      fcmToken: json['fcm_token'],
    );
  }
}
