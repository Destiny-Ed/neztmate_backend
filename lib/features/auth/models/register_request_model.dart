class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String role; // "Tenant" | "Landowner" | "Manager" | "Artisan"

  RegisterRequest({required this.email, required this.password, required this.fullName, required this.role});

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
    );
  }
}
