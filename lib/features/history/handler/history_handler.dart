import 'dart:convert';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:shelf/shelf.dart';

class HistoryHandler {
  final HistoryRepository historyRepository;

  HistoryHandler(this.historyRepository);

  /// GET /history (my recent activity)
  Future<Response> getMyHistory(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final entries = await historyRepository.getHistoryByUser(userId, limit: 30);

      return Response.ok(
        jsonEncode({'history': entries.map((e) => e.toMap()).toList(), 'message': 'Recent activity loaded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('History error: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load history'}));
    }
  }
}
