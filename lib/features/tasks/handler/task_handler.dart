import 'dart:convert';
import 'package:neztmate_backend/features/tasks/models/task_model.dart';
import 'package:neztmate_backend/features/tasks/repository/task_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class TaskHandler {
  final TaskRepository repository;

  TaskHandler(this.repository);

  /// POST /tasks - Manager assigns a task to an artisan (linked to a request)
  Future<Response> createTask(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'manager') {
        return Response(403, body: jsonEncode({'message': 'Only managers can assign tasks'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Required fields
      if (!body.containsKey('requestId') ||
          !body.containsKey('artisanId') ||
          !body.containsKey('description')) {
        return Response(
          400,
          body: jsonEncode({'message': 'requestId, artisanId, and description are required'}),
        );
      }

      final task = TaskModel.fromMap(
        body,
        '',
      ).copyWith(managerId: userId, createdAt: DateTime.now(), status: 'Assigned');

      final created = await repository.createTask(task);

      return Response.ok(
        jsonEncode({'message': 'Task assigned successfully', 'task': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Create task error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to assign task'}));
    }
  }

  /// GET /tasks/me - Artisan views tasks assigned to them
  Future<Response> getMyTasks(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'artisan') {
        return Response(403, body: jsonEncode({'message': 'Only artisans can view their assigned tasks'}));
      }

      final tasks = await repository.getTasksByArtisan(userId);

      return Response.ok(
        jsonEncode({'tasks': tasks.map((t) => t.toMap()).toList(), 'message': 'Your assigned tasks'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my tasks error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load tasks'}));
    }
  }

  /// GET /tasks/request/<requestId> - Manager views tasks for a maintenance request
  Future<Response> getTasksByRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['requestId'];

      if (userId == null || requestId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user or request ID'}));
      }

      if (role != 'manager') {
        return Response(403, body: jsonEncode({'message': 'Only managers can view tasks for a request'}));
      }

      final tasks = await repository.getTasksByRequest(requestId);

      return Response.ok(
        jsonEncode({
          'tasks': tasks.map((t) => t.toMap()).toList(),
          'message': 'Tasks for this maintenance request',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get tasks by request error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load tasks'}));
    }
  }

  /// GET /tasks/<id> - View single task (artisan or manager)
  Future<Response> getTaskById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final taskId = request.params['id'];

      if (userId == null || taskId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      final task = await repository.getTaskById(taskId);

      // Authorization: assigned artisan or manager who created it
      final isArtisan = task.artisanId == userId;
      final isManager = task.managerId == userId || role == 'manager';

      if (!isArtisan && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      return Response.ok(jsonEncode({'task': task.toMap()}), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get task error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load task'}));
    }
  }

  /// PATCH /tasks/<id>/complete - Artisan marks task as completed
  Future<Response> completeTask(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final taskId = request.params['id'];

      if (userId == null || taskId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      if (role != 'artisan') {
        return Response(403, body: jsonEncode({'message': 'Only artisans can complete tasks'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final currentTask = await repository.getTaskById(taskId);
      if (currentTask.artisanId != userId) {
        return Response(403, body: jsonEncode({'message': 'This task is not assigned to you'}));
      }

      final updated = currentTask.copyWith(
        workSummary: body['workSummary'] as String?,
        totalCost: (body['totalCost'] as num?)?.toDouble(),
        status: 'Completed',
        completedTime: DateTime.now(),
        afterPhotos: (body['afterPhotos'] as List?)?.cast<String>(),
      );

      await repository.completeTask(taskId, updated.workSummary ?? '', updated.totalCost);

      return Response.ok(jsonEncode({'message': 'Task marked as completed'}));
    } catch (e, stack) {
      print('Complete task error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to complete task'}));
    }
  }
}
