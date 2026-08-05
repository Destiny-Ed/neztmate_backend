import 'dart:convert';
import 'package:shelf/shelf.dart';

class RateLimitEntry {
  int count;
  DateTime resetAt;

  RateLimitEntry({required this.count, required this.resetAt});
}

class RateLimiterMiddleware {
  final Map<String, RateLimitEntry> _store = {};

  // Limits by plan
  final Map<String, Map<String, ({int max, Duration window})>> _planRules = {
    'free': {
      'auth': (max: 10, window: Duration(minutes: 15)),
      'applications': (max: 5, window: Duration(hours: 1)),
      'default': (max: 60, window: Duration(minutes: 1)),
      'payments': (max: 20, window: Duration(minutes: 1)),
    },
    'basic': {
      'auth': (max: 15, window: Duration(minutes: 15)),
      'applications': (max: 15, window: Duration(hours: 1)),
      'default': (max: 120, window: Duration(minutes: 1)),
      'payments': (max: 40, window: Duration(minutes: 1)),
    },
    'premium': {
      'auth': (max: 30, window: Duration(minutes: 15)),
      'applications': (max: 50, window: Duration(hours: 1)),
      'default': (max: 300, window: Duration(minutes: 1)),
      'payments': (max: 100, window: Duration(minutes: 1)),
    },
    'enterprise': {
      'auth': (max: 100, window: Duration(minutes: 15)),
      'applications': (max: 200, window: Duration(hours: 1)),
      'default': (max: 1000, window: Duration(minutes: 1)),
      'payments': (max: 300, window: Duration(minutes: 1)),
    },
  };

  Middleware get middleware => (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;

      // Skip health & webhook
      if (path == 'health' || path.contains('webhook')) {
        return innerHandler(request);
      }

      final userId = request.context['userId'] as String?;
      final plan = request.context['subscriptionPlan'] as String? ?? 'free';
      final clientKey = userId != null ? 'user:$userId' : 'ip:${_getIp(request)}';

      final rule = _getRule(path, plan);
      final now = DateTime.now();
      final entry = _store[clientKey];

      if (entry == null || now.isAfter(entry.resetAt)) {
        _store[clientKey] = RateLimitEntry(count: 1, resetAt: now.add(rule.window));
      } else {
        if (entry.count >= rule.max) {
          final retryAfter = entry.resetAt.difference(now).inSeconds;

          return Response(
            429,
            body: jsonEncode({
              'message': plan == 'free'
                  ? 'Rate limit exceeded. Upgrade to Premium for higher limits.'
                  : 'Too many requests. Please try again later.',
              'retryAfter': retryAfter,
              if (plan == 'free') 'upgradeUrl': '/subscriptions/plans',
            }),
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': retryAfter.toString(),
              'X-RateLimit-Limit': rule.max.toString(),
              'X-RateLimit-Remaining': '0',
            },
          );
        }
        entry.count++;
      }

      final remaining = rule.max - (_store[clientKey]?.count ?? 0);
      final response = await innerHandler(request);

      return response.change(
        headers: {
          ...response.headers,
          'X-RateLimit-Limit': rule.max.toString(),
          'X-RateLimit-Remaining': remaining.clamp(0, rule.max).toString(),
        },
      );
    };
  };

  ({int max, Duration window}) _getRule(String path, String plan) {
    final rules = _planRules[plan] ?? _planRules['free']!;

    if (path.startsWith('auth')) return rules['auth']!;
    if (path.contains('applications')) return rules['applications']!;
    if (path.contains('payments')) return rules['payments']!;
    return rules['default']!;
  }

  String _getIp(Request request) {
    return request.headers['x-forwarded-for'] ?? request.headers['x-real-ip'] ?? 'unknown';
  }
}

// class RateLimiterMiddleware {
//   // In-memory store (good for single instance). TODO: For multi-instance use Redis later.
//   final Map<String, RateLimitEntry> _store = {};

//   // Different limits for different routes
//   final Map<String, ({int max, Duration window})> _rules = {
//     'auth': (max: 10, window: Duration(minutes: 15)),
//     'applications': (max: 5, window: Duration(hours: 1)),
//     'payments': (max: 30, window: Duration(minutes: 1)),
//     'default': (max: 120, window: Duration(minutes: 1)),
//   };

//   Middleware get middleware => (Handler innerHandler) {
//     return (Request request) async {
//       final path = request.url.path;
//       final clientKey = _getClientKey(request);

//       // Skip rate limit for health & webhook
//       if (path == 'health' || path.contains('webhook')) {
//         return innerHandler(request);
//       }

//       final rule = _getRule(path);
//       final now = DateTime.now();

//       final entry = _store[clientKey];

//       if (entry == null || now.isAfter(entry.resetAt)) {
//         // First request or window expired
//         _store[clientKey] = RateLimitEntry(count: 1, resetAt: now.add(rule.window));
//       } else {
//         if (entry.count >= rule.max) {
//           final retryAfter = entry.resetAt.difference(now).inSeconds;

//           return Response(
//             429,
//             body: jsonEncode({
//               'message': 'Too many requests. Please try again later after $retryAfter seconds.',
//               'retryAfter': retryAfter,
//             }),
//             headers: {
//               'Content-Type': 'application/json',
//               'Retry-After': retryAfter.toString(),
//               'X-RateLimit-Limit': rule.max.toString(),
//               'X-RateLimit-Remaining': '0',
//               'X-RateLimit-Reset': entry.resetAt.millisecondsSinceEpoch.toString(),
//             },
//           );
//         }

//         entry.count++;
//       }

//       final remaining = rule.max - (_store[clientKey]?.count ?? 0);

//       final response = await innerHandler(request);

//       return response.change(
//         headers: {
//           ...response.headers,
//           'X-RateLimit-Limit': rule.max.toString(),
//           'X-RateLimit-Remaining': remaining.clamp(0, rule.max).toString(),
//           'X-RateLimit-Reset': (_store[clientKey]?.resetAt.millisecondsSinceEpoch ?? 0).toString(),
//         },
//       );
//     };
//   };

//   String _getClientKey(Request request) {
//     final userId = request.context['userId'] as String?;
//     final ip = request.headers['x-forwarded-for'] ?? request.headers['x-real-ip'] ?? 'unknown';

//     // Prefer userId when available, otherwise fall back to IP
//     return userId != null ? 'user:$userId' : 'ip:$ip';
//   }

//   ({int max, Duration window}) _getRule(String path) {
//     if (path.startsWith('auth')) return _rules['auth']!;
//     if (path.contains('applications')) return _rules['applications']!;
//     if (path.contains('payments')) return _rules['payments']!;
//     return _rules['default']!;
//   }

//   /// Optional: Clean expired entries periodically
//   void cleanup() {
//     final now = DateTime.now();
//     _store.removeWhere((_, entry) => now.isAfter(entry.resetAt));
//   }
// }
