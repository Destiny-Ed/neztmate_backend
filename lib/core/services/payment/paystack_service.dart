// lib/core/services/payment/paystack_service.dart
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaystackService {
  final String secretKey; // sk_test_ or sk_live_
  final String baseUrl = 'https://api.paystack.co';

  PaystackService(this.secretKey);

  // Step 1: Initialize transaction
  Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required double amount, // in kobo (₦100 = 10000)
    required String reference,
    String? callbackUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/initialize'),
      headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'amount': (amount * 100).toInt(), // Convert to kobo
        'reference': reference,
        'callback_url': callbackUrl,
        'metadata': metadata,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to initialize payment');
    }
    return data['data'];
  }

  // Step 2: Verify transaction (called from webhook or manually)
  Future<Map<String, dynamic>> verifyTransaction(String reference) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transaction/verify/$reference'),
      headers: {'Authorization': 'Bearer $secretKey'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Verification failed');
    }
    return data['data'];
  }

  bool verifySignature(String payload, String? signature) {
    if (signature == null) return false;

    final hmac = Hmac(sha512, utf8.encode("paystackSecretKey"));
    final digest = hmac.convert(utf8.encode(payload));
    final expectedSignature = 'sha512=${digest.toString()}';

    return signature == expectedSignature;
  }
}
