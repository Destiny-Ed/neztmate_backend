import 'dart:convert';

import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/email/resend_email_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for transactional + campaign emails (Resend).
///
/// POST /emails/send      – single email (auth)
/// POST /emails/campaign  – broadcast by role / partner (auth, elevated)
/// POST /emails/welcome   – resend welcome to a user by id (auth, elevated)
class EmailHandler {
  final ResendEmailService emailService;
  final UserRepository userRepository;

  EmailHandler(this.emailService, this.userRepository);

  static bool _isElevated(String? role) {
    final r = (role ?? '').toLowerCase().trim();
    return r == 'platform_admin' ||
        r == 'super_admin' ||
        r == 'partner_admin' ||
        r == 'admin' ||
        r == 'landowner' ||
        r == 'manager';
  }

  /// POST /emails/send
  /// Body: { to, subject, html, text?, tags? }
  Future<Response> send(Request req) async {
    try {
      if (!emailService.isConfigured) {
        return Response(
          503,
          body: jsonEncode({'message': 'Email service is not configured (RESEND_API_KEY)'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final to = (body['to'] as String?)?.trim() ?? '';
      final subject = (body['subject'] as String?)?.trim() ?? '';
      final html = (body['html'] as String?)?.trim() ?? '';
      final text = (body['text'] as String?)?.trim();

      if (to.isEmpty || !to.contains('@')) {
        return badRequest('Valid "to" email is required');
      }
      if (subject.isEmpty) return badRequest('"subject" is required');
      if (html.isEmpty) return badRequest('"html" is required');

      final tags = <String, String>{};
      if (body['tags'] is Map) {
        (body['tags'] as Map).forEach((k, v) {
          if (k != null && v != null) tags[k.toString()] = v.toString();
        });
      }

      final result = await emailService.send(
        to: to,
        subject: subject,
        html: html,
        text: text,
        tags: tags.isEmpty ? null : tags,
      );

      if (!result.success) {
        return Response(
          result.statusCode > 0 ? result.statusCode : 502,
          body: jsonEncode({'message': result.error ?? 'Failed to send email'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'Email sent', 'id': result.id}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, s) {
      return handleAppException(e, s);
    } catch (e, s) {
      return handleAppException(e, s);
    }
  }

  /// POST /emails/campaign
  /// Body: {
  ///   subject, html, text?,
  ///   role?: "tenant"|"landowner"|"manager"|"artisan",
  ///   partnerId?: string,   // defaults to JWT partnerId
  ///   limit?: int           // max recipients (default 100, max 500)
  /// }
  Future<Response> campaign(Request req) async {
    try {
      final role = req.context['role'] as String?;
      if (!_isElevated(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only admins, landowners, or managers can send campaigns'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (!emailService.isConfigured) {
        return Response(
          503,
          body: jsonEncode({'message': 'Email service is not configured (RESEND_API_KEY)'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final subject = (body['subject'] as String?)?.trim() ?? '';
      final html = (body['html'] as String?)?.trim() ?? '';
      final text = (body['text'] as String?)?.trim();
      final filterRole = (body['role'] as String?)?.trim();
      final jwtPartnerId = (req.context['partnerId'] as String?)?.trim() ?? '';
      final partnerId = (body['partnerId'] as String?)?.trim().isNotEmpty == true
          ? (body['partnerId'] as String).trim()
          : jwtPartnerId;
      final limitRaw = body['limit'];
      var limit = 100;
      if (limitRaw is int) {
        limit = limitRaw;
      } else if (limitRaw is String) {
        limit = int.tryParse(limitRaw) ?? 100;
      }
      if (limit < 1) limit = 1;
      if (limit > 500) limit = 500;

      if (subject.isEmpty) return badRequest('"subject" is required');
      if (html.isEmpty) return badRequest('"html" is required');

      final isPlatformAdmin = (role ?? '').toLowerCase() == 'platform_admin' ||
          (role ?? '').toLowerCase() == 'super_admin';
      if (!isPlatformAdmin && partnerId.isEmpty) {
        return badRequest('partnerId is required for campaign scope');
      }

      final users = await userRepository.listUsers(
        partnerId: isPlatformAdmin && (body['partnerId'] == null) ? null : partnerId,
        role: filterRole,
        limit: limit,
      );

      final recipients = users
          .where((u) => u.email.trim().isNotEmpty && u.email.contains('@'))
          .toList();

      if (recipients.isEmpty) {
        return Response.ok(
          jsonEncode({
            'message': 'No recipients matched filters',
            'sent': 0,
            'failed': 0,
            'total': 0,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final content = EmailTemplates.campaign(
        subject: subject,
        bodyHtml: html,
        bodyText: text,
      );

      // Resend batch max 100 — chunk
      var sent = 0;
      var failed = 0;
      final errors = <String>[];

      for (var i = 0; i < recipients.length; i += 100) {
        final chunk = recipients.sublist(
          i,
          i + 100 > recipients.length ? recipients.length : i + 100,
        );
        final batch = chunk
            .map((u) => {
                  'to': u.email,
                  'subject': content.subject,
                  'html': content.html,
                  'text': content.text,
                })
            .toList();

        final results = await emailService.sendBatch(batch);
        for (var j = 0; j < results.length; j++) {
          if (results[j].success) {
            sent++;
          } else {
            failed++;
            if (errors.length < 10) {
              errors.add('${chunk[j].email}: ${results[j].error}');
            }
          }
        }
      }

      return Response.ok(
        jsonEncode({
          'message': 'Campaign processed',
          'sent': sent,
          'failed': failed,
          'total': recipients.length,
          if (errors.isNotEmpty) 'errors': errors,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, s) {
      return handleAppException(e, s);
    } catch (e, s) {
      return handleAppException(e, s);
    }
  }

  /// POST /emails/welcome
  /// Body: { userId } — resend welcome email (elevated)
  Future<Response> resendWelcome(Request req) async {
    try {
      final role = req.context['role'] as String?;
      if (!_isElevated(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Insufficient permissions'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final userId = (body['userId'] as String?)?.trim() ?? '';
      if (userId.isEmpty) return badRequest('"userId" is required');

      final user = await userRepository.getUserById(userId);
      await emailService.sendWelcomeEmail(
        to: user.email,
        fullName: user.fullName,
        role: user.role,
      );

      return Response.ok(
        jsonEncode({'message': 'Welcome email queued', 'email': user.email}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, s) {
      return handleAppException(e, s);
    } catch (e, s) {
      return handleAppException(e, s);
    }
  }
}
