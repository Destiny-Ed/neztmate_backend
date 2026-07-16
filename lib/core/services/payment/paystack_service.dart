// lib/core/services/payment/paystack_service.dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:neztmate_backend/core/cache/app_cache.dart';
import 'dart:convert';

import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

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

    print(response.body);

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

  /// Create Subaccount for a user (called when they add payout account)
  Future<String?> createSubaccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

      final response = await http.post(
        Uri.parse('https://api.paystack.co/subaccount'),
        headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "business_name": businessName,
          "bank_code": bankCode,
          "account_number": accountNumber,
          "percentage_charge": 0, // You can charge extra if needed
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['status'] == true) {
        return data['data']['id'] as String; // subaccount id
      }
      print('Failed to create subaccount: ${data['message']}');
      return null;
    } catch (e) {
      print('Error creating subaccount: $e');
      return null;
    }
  }

  /// Transfer to Subaccount (Auto Payout)
  Future<bool> transferToSubaccount({
    required double amount, // in Naira
    required String subaccountId,
    required String reference,
    required String reason,
  }) async {
    try {
      final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

      final response = await http.post(
        Uri.parse('https://api.paystack.co/transfer'),
        headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "source": "balance",
          "amount": (amount * 100).toInt(), // to Kobo
          "recipient": subaccountId,
          "reason": reason,
          "reference": reference,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        print('✅ Transfer successful: $reference');
        return true;
      } else {
        print('❌ Transfer failed: ${data['message']}');
        return false;
      }
    } catch (e) {
      print('Error transferring to subaccount: $e');
      return false;
    }
  }

  Future<bool> deleteSubaccount(String subaccountId) async {
    try {
      final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

      final response = await http.delete(
        Uri.parse('https://api.paystack.co/subaccount/$subaccountId'),
        headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['status'] == true;
    } catch (e) {
      print('Error deleting subaccount: $e');
      return false;
    }
  }

  /// Transfer money directly to a bank account (for platform fees)
  Future<bool> transferToBank({
    required double amount, // in Naira
    required String accountNumber,
    required String bankCode,
    required String reference,
    required String reason,
  }) async {
    try {
      final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

      final response = await http.post(
        Uri.parse('https://api.paystack.co/transfer'),
        headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "source": "balance",
          "amount": (amount * 100).toInt(), // Convert to Kobo
          "recipient": null, // Will be resolved by account details
          "account_number": accountNumber,
          "bank_code": bankCode,
          "reference": reference,
          "reason": reason,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        print('✅ Bank transfer successful: $reference');
        return true;
      } else {
        print('❌ Bank transfer failed: ${data['message']}');
        return false;
      }
    } catch (e) {
      print('Error transferring to bank: $e');
      return false;
    }
  }

  /// Resolve/Verify Bank Account Number
  Future<Map<String, dynamic>> resolveBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

    final response = await http.get(
      Uri.parse('https://api.paystack.co/bank/resolve?account_number=$accountNumber&bank_code=$bankCode'),
      headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to resolve account: ${response.body}');
    }
  }

  /// GET All Nigerian Banks (for dropdowns)
  Future<List<dynamic>> getAllBanks({String country = 'nigeria'}) async {
    try {
      final cacheKey = 'all_banks_$country';

      final cached = AppCache().get<List<dynamic>>(cacheKey);
      if (cached != null) return cached;

      final secretKey = Platform.environment['PAYSTACK_SECRET_KEY'] ?? env['PAYSTACK_SECRET_KEY'];

      final response = await http.get(
        Uri.parse('https://api.paystack.co/bank?country=$country'),
        headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List<dynamic>;

        AppCache().set(cacheKey, data, ttl: const Duration(minutes: 10));
        return data;
      } else {
        throw Exception('Failed to fetch banks: ${response.body}');
      }
    } catch (e) {
      print('Paystack get banks error: $e');
      rethrow;
    }
  }
}
