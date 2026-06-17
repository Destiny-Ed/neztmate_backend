import 'dart:convert';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_request.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_task.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class MaintenanceHandler {
  final MaintenanceRepository maintenanceRepository;
  final UserRepository userRepository;
  final PropertyRepository propertyRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;
  final PaymentRepository paymentRepository;

  MaintenanceHandler({
    required this.maintenanceRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.notificationRepository,
    required this.historyRepository,
    required this.paymentRepository,
  });

  // MAINTENANCE REQUESTS

  /// POST /maintenance - Tenant creates a new maintenance request
  Future<Response> createRequest(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      if (tenantId == null) return unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final propertyId = body['propertyId'] as String?;
      final unitId = body['unitId'] as String?;
      final title = body['title'] as String?;
      final description = body['description'] as String?;
      final category = body['category'] as String?;
      final priority = body['priority'] as String? ?? 'Medium';

      if (propertyId == null || unitId == null || title == null || description == null || category == null) {
        return badRequest('propertyId, unitId, title, description and category are required');
      }

      final requestModel = MaintenanceRequestModel(
        id: '',
        tenantId: tenantId,
        propertyId: propertyId,
        unitId: unitId,
        title: title,
        description: description,
        category: category,
        priority: priority,
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      final created = await maintenanceRepository.createRequest(requestModel);

      // Notify manager/landowner
      await notificationRepository.create(
        NotificationModel(
          userId: '', // You can fetch property owner/manager here
          type: 'new_maintenance_request',
          title: 'New Maintenance Request',
          body: '$title - $category',
          relatedId: created.id,
          relatedCollection: 'maintenance_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Maintenance request created', 'request': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Create maintenance request error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /maintenance/all - Manager/Landowner sees ALL requests across their properties
  Future<Response> getAllRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Access denied'}));
      }

      final requests = await maintenanceRepository.getAllRequestsForManagerOrLandowner(userId);

      return Response.ok(
        jsonEncode({'requests': requests.map((r) => r.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get all requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /maintenance/me - Tenant sees their requests
  Future<Response> getMyRequests(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      if (tenantId == null) return unauthorized();

      final requests = await maintenanceRepository.getRequestsByTenant(tenantId);

      return Response.ok(
        jsonEncode({'requests': requests.map((r) => r.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  // TASKS

  /// POST /maintenance/<requestId>/tasks - Assign task to artisan
  Future<Response> assignTask(Request request) async {
    try {
      final managerId = request.context['userId'] as String?;
      final requestId = request.params['requestId'];

      if (managerId == null || requestId == null) {
        return badRequest('Missing request ID');
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final artisanId = body['artisanId'] as String?;
      final propertyId = body['propertyId'] as String?;
      final title = body['title'] as String?;
      final description = body['description'] as String?;

      if (artisanId == null || title == null) {
        return badRequest('artisanId and title are required');
      }

      if (propertyId == null) {
        return badRequest('propertyId is required');
      }

      final task = MaintenanceTaskModel(
        id: '',
        maintenanceRequestId: requestId,
        artisanId: artisanId,
        title: title,
        description: description,
        status: 'Pending',
        createdAt: DateTime.now(),
        assignedAt: DateTime.now(),
        assignedBy: managerId,
        propertyId: propertyId,
      );

      final created = await maintenanceRepository.createTask(task);

      // Notify artisan
      await notificationRepository.create(
        NotificationModel(
          userId: artisanId,
          type: 'task_assigned',
          title: 'New Maintenance Task',
          body: title,
          relatedId: created.id,
          relatedCollection: 'maintenance_tasks',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Task assigned successfully', 'task': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Assign task error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /tasks/<id>/accept - Artisan accepts task
  Future<Response> acceptTask(Request request) async {
    try {
      final artisanId = request.context['userId'] as String?;
      final taskId = request.params['id'];

      if (artisanId == null || taskId == null) return badRequest('Missing task ID');

      await maintenanceRepository.acceptTask(taskId, artisanId);

      return Response.ok(jsonEncode({'message': 'Task accepted successfully'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// PATCH /tasks/<id>/complete - Artisan completes task
  Future<Response> completeTask(Request request) async {
    try {
      final artisanId = request.context['userId'] as String?;
      final taskId = request.params['id'];

      if (artisanId == null || taskId == null) return badRequest('Missing task ID');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final summary = body['summary'] as String?;
      final actualCost = (body['actualCost'] as num?)?.toDouble();

      if (summary == null) return badRequest('summary is required');

      await maintenanceRepository.completeTask(taskId, summary, actualCost);

      return Response.ok(jsonEncode({'message': 'Task completed successfully'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// PATCH /tasks/<id>/approve-payment - Manager/Landowner approves payment
  Future<Response> approveTaskPayment(Request request) async {
    try {
      final approverId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final taskId = request.params['id'];

      if (approverId == null || taskId == null) {
        return badRequest('Task ID is required');
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only managers/landowners can approve payments'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final paymentMethod = body['paymentMethod'] as String?; // 'wallet', 'link', 'external'
      final notes = body['notes'] as String?;

      if (paymentMethod == null || !['wallet', 'link', 'external'].contains(paymentMethod)) {
        return badRequest('paymentMethod must be wallet, link, or external');
      }

      final task = await maintenanceRepository.getTaskById(taskId);

      if (task.status != 'Completed') {
        return Response(
          400,
          body: jsonEncode({'message': 'Task must be marked as Completed before payment approval'}),
        );
      }

      if (task.paymentStatus == 'Paid') {
        return Response(400, body: jsonEncode({'message': 'Payment already approved'}));
      }

      final amount = task.quotationAmount ?? 0.0;
      if (amount <= 0) {
        return badRequest('No valid amount to approve');
      }

      MaintenanceTaskModel updatedTask = task;

      final maintenanceRequest = await maintenanceRepository.getRequestById(task.maintenanceRequestId);

      if (paymentMethod == 'wallet') {
        // Deduct from property balance
        await paymentRepository.deductFromPropertyBalance(
          propertyId: maintenanceRequest.propertyId,
          amount: amount,
          reason: 'Payment for maintenance task: ${task.title}',
          reference: task.id,
        );

        updatedTask = task.copyWith(
          paymentStatus: 'Paid',
          paymentMethod: 'wallet',
          actualCost: amount,
          paymentApprovedAt: DateTime.now(),
          paymentApprovedBy: approverId,
        );
      } else if (paymentMethod == 'link') {
        final PaystackService paystackService = PaystackService();

        final now = DateTime.now();

        // Initialize Paystack payment
        final reference = 'task_${now.millisecondsSinceEpoch}';

        final artisan = await userRepository.getUserById(task.artisanId);

        final initData = await paystackService.initializeTransaction(
          email: artisan.email,
          amount: amount,
          reference: reference,
          metadata: {
            'userId': approverId,
            'taskId': task.id,
            'propertyId': maintenanceRequest.propertyId,
            'type': 'task_payment',
            'approverId': approverId,
            'unitId': maintenanceRequest.unitId,
          },
        );

        updatedTask = task.copyWith(
          paymentStatus: 'Pending',
          paymentMethod: paymentMethod,
          paymentReference: reference,
          actualCost: amount,
          paymentApprovedAt: now,
          paymentApprovedBy: approverId,
        );

        // Save pending payment
        final pendingPayment = PaymentModel(
          id: '',
          taskId: taskId,
          payerId: approverId,
          propertyId: maintenanceRequest.propertyId,
          unitId: maintenanceRequest.unitId,
          amount: amount,
          status: 'Pending',
          method: 'Paystack',
          transactionRef: reference,
          type: 'task_payment',
          createdAt: now,
        );

        await paymentRepository.createPayment(pendingPayment);

        // Return payment link to frontend
        return Response.ok(
          jsonEncode({
            'message': 'Payment link generated',
            'task': updatedTask.toMap(),
            'authorization_url': initData['authorization_url'],
            'reference': reference,
            'paymentMethod': paymentMethod,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else if (paymentMethod == 'external') {
        // Just mark as paid (outside the app)
        updatedTask = task.copyWith(
          paymentStatus: 'Paid',
          paymentMethod: 'external',
          actualCost: amount,
          paymentApprovedAt: DateTime.now(),
          paymentApprovedBy: approverId,
        );
      }

      // Save updated task
      await maintenanceRepository.updateTask(updatedTask);

      // Send notifications
      await _sendPaymentApprovalNotifications(updatedTask, approverId);

      return Response.ok(
        jsonEncode({
          'message': 'Payment approved successfully',
          'task': updatedTask.toMap(),
          'paymentMethod': paymentMethod,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Approve task payment error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to approve payment'}));
    }
  }

  // Helper method
  Future<void> _sendPaymentApprovalNotifications(MaintenanceTaskModel task, String approverId) async {
    // Notify Artisan
    await notificationRepository.create(
      NotificationModel(
        userId: task.artisanId,
        type: 'payment_approved',
        title: 'Payment Approved',
        body: 'Your payment for "${task.title}" has been approved.',
        relatedId: task.id,
        relatedCollection: 'maintenance_tasks',
        createdAt: DateTime.now(),
        id: '',
      ),
    );

    // Notify Tenant (optional)
    final request = await maintenanceRepository.getRequestById(task.maintenanceRequestId);
    await notificationRepository.create(
      NotificationModel(
        userId: request.tenantId,
        type: 'task_payment_approved',
        title: 'Task Payment Processed',
        body: 'Payment for maintenance task has been approved.',
        relatedId: task.id,
        relatedCollection: 'maintenance_tasks',
        createdAt: DateTime.now(),
        id: '',
      ),
    );
  }

  Response badRequest(String message) => Response(400, body: jsonEncode({'message': message}));
  Response unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
