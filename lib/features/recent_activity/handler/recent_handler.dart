// import 'dart:convert';

// import 'package:neztmate_backend/features/recent_activity/models/recent_model.dart';
// import 'package:shelf/shelf.dart';

// class RecentHandler {
//   Future<Response> getRecentActivity(Request request) async {
//     try {
//       final userId = request.context['userId'] as String?;
//       if (userId == null) {
//         return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
//       }

//       final snapshot = await firestore
//           .collection('users')
//           .doc(userId)
//           .collection('recent_activities')
//           .orderBy('timestamp', descending: true)
//           .limit(20)
//           .get();

//       final activities = snapshot.docs.map((doc) {
//         return RecentActivity.fromMap(doc.data(), doc.id);
//       }).toList();

//       return Response.ok(
//         jsonEncode({
//           'activities': activities.map((a) => a.toMap()).toList(),
//           'message': 'Recent activity loaded',
//         }),
//         headers: {'Content-Type': 'application/json'},
//       );
//     } catch (e) {
//       print('Recent activity error: $e');
//       return Response.internalServerError(body: jsonEncode({'message': 'Failed to load recent activity'}));
//     }
//   }
// }
