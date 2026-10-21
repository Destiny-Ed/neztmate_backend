import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;

class EmailSendResult {
  final bool success;
  final String? id;
  final String? error;
  final int statusCode;

  const EmailSendResult({
    required this.success,
    this.id,
    this.error,
    required this.statusCode,
  });

  Map<String, dynamic> toMap() => {
    'success': success,
    if (id != null) 'id': id,
    if (error != null) 'error': error,
    'statusCode': statusCode,
  };
}

class ResendEmailService {
  static const _baseUrl = 'https://api.resend.com';

  final env = DotEnv()..load();
  final http.Client _client;

  ResendEmailService({http.Client? client}) : _client = client ?? http.Client();

  String get _apiKey =>
      Platform.environment['RESEND_API_KEY'] ?? env['RESEND_API_KEY'] ?? '';

  String get _from =>
      Platform.environment['RESEND_FROM_EMAIL'] ??
      env['RESEND_FROM_EMAIL'] ??
      'NeztMate <onboarding@neztmate.com>';

  String? get _replyTo {
    final v = Platform.environment['RESEND_REPLY_TO'] ?? env['RESEND_REPLY_TO'];
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  String get logoUrl {
    final v = Platform.environment['RESEND_LOGO_URL'] ?? env['RESEND_LOGO_URL'];
    if (v == null || v.trim().isEmpty) return EmailTemplates.defaultLogoUrl;
    return v.trim();
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<EmailSendResult> send({
    required String to,
    required String subject,
    required String html,
    String? text,
    String? from,
    List<String>? cc,
    List<String>? bcc,
    Map<String, String>? tags,
  }) async {
    if (!isConfigured) {
      return const EmailSendResult(
        success: false,
        error: 'RESEND_API_KEY is not configured',
        statusCode: 0,
      );
    }

    final body = <String, dynamic>{
      'from': from ?? _from,
      'to': [to],
      'subject': subject,
      'html': html,
      if (text != null && text.isNotEmpty) 'text': text,
      if (_replyTo != null) 'reply_to': _replyTo,
      if (cc != null && cc.isNotEmpty) 'cc': cc,
      if (bcc != null && bcc.isNotEmpty) 'bcc': bcc,
      if (tags != null && tags.isNotEmpty)
        'tags': tags.entries
            .map((e) => {'name': e.key, 'value': e.value})
            .toList(),
    };

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return EmailSendResult(
          success: true,
          id: decoded['id'] as String?,
          statusCode: response.statusCode,
        );
      }

      final errMsg =
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          response.body;
      return EmailSendResult(
        success: false,
        error: errMsg,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return EmailSendResult(
        success: false,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  Future<void> sendWelcomeEmail({
    required String to,
    required String fullName,
    required String role,
  }) async {
    final templates = EmailTemplates.welcome(fullName: fullName, role: role);
    final result = await send(
      to: to,
      subject: templates.subject,
      html: templates.html,
      text: templates.text,
      tags: {'type': 'welcome', 'role': role.toLowerCase()},
    );
    if (!result.success) {
      print(
        '[ResendEmailService] welcome email failed for $to: ${result.error}',
      );
    } else {
      print('[ResendEmailService] welcome email sent to $to id=${result.id}');
    }
  }

  Future<EmailSendResult> sendVerificationOtp({
    required String to,
    required String fullName,
    required String code,
  }) async {
    final templates = EmailTemplates.verificationOtp(
      fullName: fullName,
      code: code,
    );
    final result = await send(
      to: to,
      subject: templates.subject,
      html: templates.html,
      text: templates.text,
      tags: {'type': 'email_verification'},
    );
    if (!result.success) {
      print(
        '[ResendEmailService] verification OTP failed for $to: ${result.error}',
      );
    } else {
      print(
        '[ResendEmailService] verification OTP sent to $to id=${result.id}',
      );
    }
    return result;
  }

  Future<EmailSendResult> sendPasswordResetOtp({
    required String to,
    required String fullName,
    required String code,
  }) async {
    final templates = EmailTemplates.passwordResetOtp(
      fullName: fullName,
      code: code,
    );
    final result = await send(
      to: to,
      subject: templates.subject,
      html: templates.html,
      text: templates.text,
      tags: {'type': 'password_reset'},
    );
    if (!result.success) {
      print(
        '[ResendEmailService] password reset OTP failed for $to: ${result.error}',
      );
    } else {
      print(
        '[ResendEmailService] password reset OTP sent to $to id=${result.id}',
      );
    }
    return result;
  }

  /// Send up to 100 emails in one Resend batch request.
  /// [emails] items: { to, subject, html, text? }
  Future<List<EmailSendResult>> sendBatch(
    List<Map<String, dynamic>> emails,
  ) async {
    if (!isConfigured) {
      return List.generate(
        emails.length,
        (_) => const EmailSendResult(
          success: false,
          error: 'RESEND_API_KEY is not configured',
          statusCode: 0,
        ),
      );
    }

    if (emails.isEmpty) return [];

    if (emails.length > 100) {
      throw ArgumentError('Resend batch supports max 100 emails per request');
    }

    final payload = emails.map((e) {
      final to = e['to'];
      return <String, dynamic>{
        'from': e['from'] ?? _from,
        'to': to is List ? to : [to],
        'subject': e['subject'],
        'html': e['html'],
        if (e['text'] != null && (e['text'] as String).isNotEmpty)
          'text': e['text'],
        if (_replyTo != null) 'reply_to': _replyTo,
      };
    }).toList();

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/emails/batch'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : (decoded is List ? decoded : <dynamic>[]);

        return List.generate(emails.length, (i) {
          if (i < list.length) {
            final item = list[i];
            final id = item is Map ? item['id']?.toString() : null;
            return EmailSendResult(
              success: true,
              id: id,
              statusCode: response.statusCode,
            );
          }
          return EmailSendResult(
            success: true,
            statusCode: response.statusCode,
          );
        });
      }

      final errMsg = decoded is Map
          ? (decoded['message']?.toString() ??
                decoded['error']?.toString() ??
                response.body)
          : response.body;

      return List.generate(
        emails.length,
        (_) => EmailSendResult(
          success: false,
          error: errMsg,
          statusCode: response.statusCode,
        ),
      );
    } catch (e) {
      return List.generate(
        emails.length,
        (_) =>
            EmailSendResult(success: false, error: e.toString(), statusCode: 0),
      );
    }
  }
}

class EmailContent {
  final String subject;
  final String html;
  final String text;

  const EmailContent({
    required this.subject,
    required this.html,
    required this.text,
  });
}

class EmailTemplates {
  EmailTemplates._();

  static const defaultLogoUrl = 'https://neztmate.com/assets/logo_bg.png';

  static String get logoUrl {
    final v = Platform.environment['RESEND_LOGO_URL'];
    if (v != null && v.trim().isNotEmpty) return v.trim();
    return defaultLogoUrl;
  }

  static String _escape(String s) => s
      .replaceAll('&', '&')
      .replaceAll('<', '<')
      .replaceAll('>', '>')
      .replaceAll('"', '"');

  static String _layout({
    required String title,
    required String bodyHtml,
    String? logoUrl,
  }) {
    final logo = logoUrl ?? EmailTemplates.logoUrl;
    return '<!DOCTYPE html><html><head><meta charset="utf-8"/><title>' +
        title +
        '</title></head><body style="margin:0;padding:0;background:#f4f6f8;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">' +
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f4f6f8;padding:32px 16px;"><tr><td align="center">' +
        '<table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;border-radius:12px;overflow:hidden;max-width:560px;width:100%;">' +
        '<tr><td align="center" style="padding:28px 32px;"><img src="' +
        logo +
        '" width="160" alt="NeztMate" style="display:block;margin:0 auto;max-width:160px;height:auto;border:0;" />' +
        '<p style="margin:12px 0 0;color:#0f766e;font-size:13px;font-weight:500;">Housing, clarified</p></td></tr>' +
        '<tr><td style="padding:32px;color:#1f2937;font-size:15px;line-height:1.6;">' +
        bodyHtml +
        '</td></tr>' +
        '<tr><td style="padding:0 32px 28px;color:#9ca3af;font-size:12px;"><p style="border-top:1px solid #e5e7eb;padding-top:20px;margin:0;">You are receiving this because you have a NeztMate account.<br/>(c) NeztMate - neztmate.com</p></td></tr>' +
        '</table></td></tr></table></body></html>';
  }

  static EmailContent welcome({
    required String fullName,
    required String role,
  }) {
    final name = _escape(fullName.trim().isEmpty ? 'there' : fullName.trim());
    final roleLabel = _escape(role);
    final subject = 'Welcome to NeztMate, $fullName!';
    final body =
        '<p style="margin:0 0 16px;">Hi ' +
        name +
        ',</p><p style="margin:0 0 16px;">Welcome to <strong>NeztMate</strong> - your account as a <strong>' +
        roleLabel +
        '</strong> is ready.</p><p style="margin:0 0 8px;">Next steps:</p><ul style="margin:0 0 16px;padding-left:20px;"><li>Complete your profile</li><li>Verify your identity</li><li>Explore properties and services</li></ul><p style="margin:24px 0 0;color:#6b7280;font-size:13px;">If you did not create this account, ignore this email.</p>';
    final text =
        'Hi $fullName,\n\nWelcome to NeztMate - your $role account is ready.\n\nhttps://neztmate.com';
    return EmailContent(
      subject: subject,
      html: _layout(title: subject, bodyHtml: body),
      text: text,
    );
  }

  static EmailContent verificationOtp({
    required String fullName,
    required String code,
  }) {
    final name = _escape(fullName.trim().isEmpty ? 'there' : fullName.trim());
    final safeCode = _escape(code);
    final subject = 'Your NeztMate verification code';
    final body =
        '<p style="margin:0 0 16px;">Hi ' +
        name +
        ',</p><p style="margin:0 0 16px;">Use this code to verify your email on <strong>NeztMate</strong>:</p><p style="margin:24px 0;text-align:center;"><span style="display:inline-block;letter-spacing:8px;font-size:28px;font-weight:700;color:#0f766e;background:#f0fdfa;padding:16px 24px;border-radius:10px;border:1px solid #99f6e4;">' +
        safeCode +
        '</span></p><p style="margin:0;color:#6b7280;font-size:13px;">This code expires in 15 minutes. If you did not create an account, ignore this email.</p>';
    final text =
        'Hi $fullName,\n\nYour NeztMate verification code is: $code\n\nExpires in 15 minutes.';
    return EmailContent(
      subject: subject,
      html: _layout(title: subject, bodyHtml: body),
      text: text,
    );
  }

  static EmailContent passwordResetOtp({
    required String fullName,
    required String code,
  }) {
    final name = _escape(fullName.trim().isEmpty ? 'there' : fullName.trim());
    final safeCode = _escape(code);
    final subject = 'Reset your NeztMate password';
    final body =
        '<p style="margin:0 0 16px;">Hi ' +
        name +
        ',</p><p style="margin:0 0 16px;">Use this code to reset your <strong>NeztMate</strong> password:</p><p style="margin:24px 0;text-align:center;"><span style="display:inline-block;letter-spacing:8px;font-size:28px;font-weight:700;color:#0f766e;background:#f0fdfa;padding:16px 24px;border-radius:10px;border:1px solid #99f6e4;">' +
        safeCode +
        '</span></p><p style="margin:0;color:#6b7280;font-size:13px;">This code expires in 15 minutes. If you did not request a password reset, ignore this email.</p>';
    final text =
        'Hi $fullName,\n\nYour NeztMate password reset code is: $code\n\nExpires in 15 minutes.\n\nIf you did not request this, ignore this email.';
    return EmailContent(
      subject: subject,
      html: _layout(title: subject, bodyHtml: body),
      text: text,
    );
  }

  static EmailContent campaign({
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) {
    final text =
        bodyText ??
        bodyHtml
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return EmailContent(
      subject: subject,
      html: _layout(title: _escape(subject), bodyHtml: bodyHtml),
      text: text,
    );
  }

  static EmailContent custom({
    required String subject,
    required String htmlBody,
    String? text,
  }) {
    return EmailContent(
      subject: subject,
      html: _layout(title: _escape(subject), bodyHtml: htmlBody),
      text: text ?? htmlBody.replaceAll(RegExp(r'<[^>]+>'), ' ').trim(),
    );
  }
}
