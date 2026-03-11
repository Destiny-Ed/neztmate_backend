class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String role;

  RegisterRequest({required this.email, required this.password, required this.fullName, required this.role});

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      email: json['email'],
      password: json['password'],
      fullName: json['full_name'],
      role: json['role'],
    );
  }
}
