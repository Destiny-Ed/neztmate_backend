import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;

/// Result of a single email send via Resend.
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

/// Thin client for https://resend.com email API.
///
/// Env:
///   RESEND_API_KEY   – required (re_...)
///   RESEND_FROM_EMAIL – e.g. "NeztMate <onboarding@neztmate.com>"
///   RESEND_REPLY_TO   – optional
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

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Send one email.
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
        'tags': tags.entries.map((e) => {'name': e.key, 'value': e.value}).toList(),
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

      final errMsg = decoded['message']?.toString() ??
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

  /// Batch send (Resend accepts up to 100 per request).
  /// Each item: { to, subject, html, text? }
  Future<List<EmailSendResult>> sendBatch(List<Map<String, dynamic>> emails) async {
    if (!isConfigured) {
      return emails
          .map((_) => const EmailSendResult(
                success: false,
                error: 'RESEND_API_KEY is not configured',
                statusCode: 0,
              ))
          .toList();
    }
    if (emails.isEmpty) return [];

    final payload = emails.map((e) {
      return {
        'from': e['from'] ?? _from,
        'to': e['to'] is List ? e['to'] : [e['to']],
        'subject': e['subject'],
        'html': e['html'],
        if (e['text'] != null) 'text': e['text'],
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        List list;
        if (decoded is Map && decoded['data'] is List) {
          list = decoded['data'] as List;
        } else if (decoded is List) {
          list = decoded;
        } else {
          list = [];
        }
        return List.generate(emails.length, (i) {
          final id = i < list.length ? (list[i] as Map?)?['id'] as String? : null;
          return EmailSendResult(
            success: true,
            id: id,
            statusCode: response.statusCode,
          );
        });
      }

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final errMsg = decoded['message']?.toString() ?? response.body;
      return emails
          .map((_) => EmailSendResult(
                success: false,
                error: errMsg,
                statusCode: response.statusCode,
              ))
          .toList();
    } catch (e) {
      return emails
          .map((_) => EmailSendResult(
                success: false,
                error: e.toString(),
                statusCode: 0,
              ))
          .toList();
    }
  }

  /// Fire-and-forget welcome email for new sign-ups. Never throws.
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
      print('[ResendEmailService] welcome email failed for $to: ${result.error}');
    } else {
      print('[ResendEmailService] welcome email sent to $to id=${result.id}');
    }
  }
}

/// Simple subject + html + text bundle.
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

/// Built-in HTML templates for transactional + campaign emails.
class EmailTemplates {
  EmailTemplates._();

  static String _escape(String s) => s
      .replaceAll('&', '&')
      .replaceAll('<', '<')
      .replaceAll('>', '>')
      .replaceAll('"', '"');

  static String _layout({required String title, required String bodyHtml}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>$title</title>
</head>
<body style="margin:0;padding:0;background:#f4f6f8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f8;padding:32px 16px;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:#0f766e;padding:24px 32px;">
              <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;">NeztMate</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;color:#1f2937;font-size:15px;line-height:1.6;">
              $bodyHtml
            </td>
          </tr>
          <tr>
            <td style="padding:16px 32px 28px;color:#9ca3af;font-size:12px;line-height:1.5;">
              You’re receiving this because you have a NeztMate account.<br/>
              © NeztMate · <a href="https://neztmate.com" style="color:#0f766e;">neztmate.com</a>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  static EmailContent welcome({
    required String fullName,
    required String role,
  }) {
    final name = _escape(fullName.trim().isEmpty ? 'there' : fullName.trim());
    final roleLabel = _escape(role);
    final subject = 'Welcome to NeztMate, $fullName!';
    final body = '''
<p>Hi $name,</p>
<p>Welcome to <strong>NeztMate</strong> — your account as a <strong>$roleLabel</strong> is ready.</p>
<p>Here’s what you can do next:</p>
<ul>
  <li>Complete your profile so landlords and tenants can find you</li>
  <li>Verify your identity for faster applications and trust</li>
  <li>Explore properties, units, and services on the app</li>
</ul>
<p style="margin-top:24px;">
  <a href="https://neztmate.com" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;padding:12px 24px;border-radius:8px;font-weight:600;">Open NeztMate</a>
</p>
<p style="margin-top:24px;">If you didn’t create this account, you can ignore this email.</p>
''';
    final text = '''
Hi $fullName,

Welcome to NeztMate — your $role account is ready.

Next steps:
- Complete your profile
- Verify your identity
- Explore properties and services in the app

https://neztmate.com

If you didn’t create this account, ignore this email.
''';
    return EmailContent(
      subject: subject,
      html: _layout(title: subject, bodyHtml: body),
      text: text.trim(),
    );
  }

  static EmailContent campaign({
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) {
    final text = bodyText ??
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
