import 'dart:convert';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class HistoryHandler {
  final HistoryRepository historyRepository;

  HistoryHandler(this.historyRepository);

  /// GET /history — my recent activity (partner-scoped)
  Future<Response> getMyHistory(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = request.context['partnerId'] as String?;

      if (userId == null || partnerId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final limitParam = request.url.queryParameters['limit'];
      final typeFilter = request.url.queryParameters['type'];
      final limit = int.tryParse(limitParam ?? '30') ?? 30;

      final entries = await historyRepository.getHistoryByUser(
        userId,
        partnerId: partnerId,
        limit: limit.clamp(1, 100),
        typeFilter: typeFilter,
      );

      return Response.ok(
        jsonEncode({'history': entries.map((e) => e.toMap()).toList(), 'message': 'Recent activity loaded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('History error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load history'}));
    }
  }

  /// GET /history/related/<collection>/<id> — activity for an entity
  Future<Response> getHistoryByRelated(Request request) async {
    try {
      final partnerId = request.context['partnerId'] as String?;
      final collection = request.params['collection'];
      final relatedId = request.params['id'];

      if (collection == null || relatedId == null || partnerId == null) {
        return Response(400, body: jsonEncode({'message': 'collection, partnerId and id are required'}));
      }

      final entries = await historyRepository.getHistoryByRelatedId(
        relatedId,
        collection,
        partnerId: partnerId,
      );

      return Response.ok(
        jsonEncode({'history': entries.map((e) => e.toMap()).toList(), 'message': 'Related history loaded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Related history error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load related history'}));
    }
  }
}
