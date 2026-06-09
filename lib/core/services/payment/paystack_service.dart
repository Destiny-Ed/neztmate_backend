// lib/core/services/payment/paystack_service.dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaystackService {
  final String baseUrl = 'https://api.paystack.co';

  final env = DotEnv()..load();

  // Step 1: Initialize transaction
  Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required double amount, // in kobo (₦100 = 10000)
    required String reference,
    String? callbackUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];
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
    final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

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

    final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

    if (secretKey == null || secretKey.isEmpty) {
      print('PAYSTACK_SECRET_KEY not found in environment');
      return false;
    }

    try {
      final key = utf8.encode(secretKey);
      final bytes = utf8.encode(payload);
      final hmac = Hmac(sha512, key);
      final digest = hmac.convert(bytes);

      final expectedSignature = digest.toString(); // ← NO "sha512=" prefix

      final isValid = signature == expectedSignature;

      print('🔐 Signature Check:');
      print('Received : $signature');
      print('Expected : $expectedSignature');
      print('Match    : ${isValid ? "✅ YES" : "❌ NO"}');

      return isValid;
    } catch (e) {
      print('Signature verification error: $e');
      return false;
    }
  }
}
