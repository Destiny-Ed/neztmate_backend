import 'dart:convert';
import 'dart:developer';
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
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class MaintenanceHandler {
  final MaintenanceRepository maintenanceRepository;
  final UserRepository userRepository;
  final PropertyRepository propertyRepository;
  final UnitRepository unitRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;
  final PaymentRepository paymentRepository;

  MaintenanceHandler({
    required this.maintenanceRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.unitRepository,
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

      final enrichedRequest = await Future.wait(
        requests.map((request) async {
          final user = await userRepository.getUserById(request.tenantId);

          final property = await propertyRepository.getPropertyById(request.propertyId);

          final unit = await unitRepository.getUnitById(request.unitId);

          return {
            ...request.toMap(),
            'propertyName': property.name,
            'tenantName': user.fullName,
            "unit": unit.unitNumber,
          };
        }),
      );

      return Response.ok(
        jsonEncode({'requests': enrichedRequest}),
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
    } catch (e, s) {
      print("errorororo ::: $e $s");
      return Response.internalServerError();
    }
  }

  /// GET /maintenance/<id> - Get single maintenance request with full details
  Future<Response> getRequestById(Request request) async {
    try {
      final currentUserId = request.context['userId'] as String?;
      final userRole = request.context['role'] as String?;

      if (currentUserId == null) return unauthorized();

      final requestId = request.params['id'];
      if (requestId == null) {
        return badRequest('Request ID is required');
      }

      final maintRequest = await maintenanceRepository.getRequestById(requestId);

      // Authorization: Tenant who created it OR Manager/Landowner of the property
      final isTenant = maintRequest.tenantId == currentUserId;
      final isManagerOrOwner = ['landowner', 'manager'].contains(userRole);

      if (!isTenant && !isManagerOrOwner) {
        return Response(403, body: jsonEncode({'message': 'You do not have access to this request'}));
      }

      // Enrich data
      final tenant = await userRepository.getUserById(maintRequest.tenantId);
      final property = await propertyRepository.getPropertyById(maintRequest.propertyId);
      final unit = await unitRepository.getUnitById(maintRequest.unitId);

      // Get all tasks related to this request
      final tasks = await maintenanceRepository.getTasksByRequest(requestId);

      // Enrich tasks + calculate total payments
      double totalPayments = 0.0;
      final enrichedTasks = await Future.wait(
        tasks.map((task) async {
          final artisan = await userRepository.getUserById(task.artisanId);

          // Sum payment/quoted amount
          final taskAmount = task.actualCost ?? task.quotationAmount ?? 0.0;
          totalPayments += taskAmount;
          return {
            ...task.toMap(),
            'artisan': {
              'id': artisan.id,
              'fullName': artisan.fullName,
              'phone': artisan.phone,
              'profilePhotoUrl': artisan.profilePhotoUrl,
              'primarySkill': artisan.primarySkill,
              'rating': artisan.rating,
            },
          };
        }),
      );

      final response = {
        ...maintRequest.toMap(),
        'tenant': {
          'id': tenant.id,
          'fullName': tenant.fullName,
          'email': tenant.email,
          'phone': tenant.phone,
          'profilePhotoUrl': tenant.profilePhotoUrl,
        },
        'property': {
          'id': property.id,
          'name': property.name,
          'address': property.address,
          'type': property.type,
        },
        'unit': {
          'id': unit.id,
          'unitNumber': unit.unitNumber,
          'bedrooms': unit.bedrooms,
          'bathrooms': unit.bathrooms,
        },
        'tasks': enrichedTasks,
        'totalTasks': enrichedTasks.length,
        'totalPayments': totalPayments,
      };

      return Response.ok(
        jsonEncode({'request': response, 'message': 'Maintenance request fetched successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get request by id error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to fetch maintenance request'}),
      );
    }
  }

  // TASKS

  /// POST /maintenance/<requestId>/tasks - Assign task to artisan
  Future<Response> assignTask(Request request) async {
    try {
      final managerId = request.context['userId'] as String?;
      final userRole = request.context['role'] as String?;
      final requestId = request.params['requestId'];

      if (managerId == null || requestId == null) {
        return badRequest('Missing request ID or authentication');
      }

      if (!['manager', 'landowner'].contains(userRole)) {
        return Response(403, body: jsonEncode({'message': 'Only managers or landowners can assign tasks'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final artisanId = body['artisanId'] as String?;
      final propertyId = body['propertyId'] as String?;

      if (artisanId == null) return badRequest('artisanId is required');
      if (propertyId == null) return badRequest('propertyId is required');

      final maintenanceRequest = await maintenanceRepository.getRequestById(requestId);

      final propertyRequest = await propertyRepository.getPropertyById(propertyId);

      //  VALIDATION: Prevent assigning to already assigned artisan
      final existingTasks = await maintenanceRepository.getTasksByRequest(requestId);
      final alreadyAssigned = existingTasks.any(
        (task) =>
            task.artisanId == artisanId && !['Completed', 'Rejected', 'Cancelled'].contains(task.status),
      );

      if (alreadyAssigned) {
        return Response(
          409,
          body: jsonEncode({'message': 'This artisan is already assigned to this maintenance request'}),
        );
      }

      // Create new task
      final task = MaintenanceTaskModel(
        id: '',
        maintenanceRequestId: requestId,
        artisanId: artisanId,
        title: maintenanceRequest.title,
        description: maintenanceRequest.description,
        category: maintenanceRequest.category,
        priority: maintenanceRequest.priority,
        status: 'Pending',
        createdAt: DateTime.now(),
        assignedAt: DateTime.now(),
        assignedBy: managerId,
        propertyId: propertyId,
      );

      final createdTask = await maintenanceRepository.createTask(task);

      // Send notification to artisan
      await notificationRepository.create(
        NotificationModel(
          userId: artisanId,
          type: 'task_assigned',
          title: 'New Maintenance Task Assigned',
          body: '${maintenanceRequest.title} - ${propertyRequest.name}',
          relatedId: createdTask.id,
          relatedCollection: 'maintenance_tasks',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      // Optional: Log to history
      // await historyRepository.createHistoryEntry(...);

      return Response.ok(
        jsonEncode({'message': 'Task assigned successfully', 'task': createdTask.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Assign task error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to assign task'}));
    }
  }

  /// DELETE /maintenance/tasks/<taskId>/remove - Remove assigned artisan (only if status is Pending)
  Future<Response> removeAssignedArtisan(Request request) async {
    try {
      final managerId = request.context['userId'] as String?;
      final userRole = request.context['role'] as String?;
      final taskId = request.params['taskId'];

      if (managerId == null || taskId == null) {
        return badRequest('Task ID is required');
      }

      if (!['manager', 'landowner'].contains(userRole)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only managers or landowners can remove task assignments'}),
        );
      }

      final task = await maintenanceRepository.getTaskById(taskId);

      // Only allow removal if task is still Pending
      if (task.status != 'Pending') {
        return Response(
          400,
          body: jsonEncode({'message': 'Can only remove artisan from tasks with Pending status'}),
        );
      }

      // Update task status to show it was removed
      final updatedTask = task.copyWith(status: 'Cancelled', updatedAt: DateTime.now());

      await maintenanceRepository.updateTask(updatedTask);

      // Notify the artisan
      await notificationRepository.create(
        NotificationModel(
          userId: task.artisanId,
          type: 'task_removed',
          title: 'Task Assignment Removed',
          body: 'Your assigned task has been removed by the manager.',
          relatedId: task.maintenanceRequestId,
          relatedCollection: 'maintenance_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Artisan assignment removed successfully', 'taskId': taskId}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Remove assigned artisan error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to remove artisan assignment'}),
      );
    }
  }

  /// PATCH /tasks/<id>/accept - Artisan accepts task
  Future<Response> acceptTask(Request request) async {
    try {
      final artisanId = request.context['userId'] as String?;
      final taskId = request.params['id'];

      if (artisanId == null || taskId == null) return badRequest('Missing task ID');

      final payoutAccounts = await paymentRepository.getDefaultPayoutAccount(artisanId);
      if (payoutAccounts == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'Please link a payout account before accepting tasks'}),
        );
      }

      await maintenanceRepository.acceptTask(taskId, artisanId);

      return Response.ok(jsonEncode({'message': 'Task accepted successfully'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// PATCH /tasks/<id>/decline - Artisan declines task
  Future<Response> declineTask(Request request) async {
    try {
      final artisanId = request.context['userId'] as String?;
      final taskId = request.params['id'];

      if (artisanId == null || taskId == null) return badRequest('Missing task ID');

      await maintenanceRepository.declineTask(taskId, artisanId);

      return Response.ok(jsonEncode({'message': 'Task declined successfully'}));
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

  /// GET /maintenance/tasks/<id> - Get detailed task with all related info + Payment Details
  Future<Response> getTaskById(Request request) async {
    try {
      final currentUserId = request.context['userId'] as String?;
      final userRole = request.context['role'] as String?;
      final taskId = request.params['id'];

      if (currentUserId == null || taskId == null) {
        return badRequest('Task ID is required');
      }

      final task = await maintenanceRepository.getTaskById(taskId);
      final maintenanceRequest = await maintenanceRepository.getRequestById(task.maintenanceRequestId);

      // Authorization check
      final isArtisan = task.artisanId == currentUserId;
      final isTenant = maintenanceRequest.tenantId == currentUserId;
      final isManagerOrOwner = ['landowner', 'manager'].contains(userRole);

      if (!isArtisan && !isTenant && !isManagerOrOwner) {
        return Response(403, body: jsonEncode({'message': 'You do not have access to this task'}));
      }

      final property = await propertyRepository.getPropertyById(task.propertyId);
      final unit = await unitRepository.getUnitById(maintenanceRequest.unitId);

      final tenant = await userRepository.getUserById(maintenanceRequest.tenantId);
      final artisan = await userRepository.getUserById(task.artisanId);
      final assignedByUser = task.assignedBy != null
          ? await userRepository.getUserById(task.assignedBy!)
          : null;

      final response = {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'category': task.category,
        'priority': task.priority,
        'status': task.status,
        'progressNotes': task.progressNotes,
        'quotedAmount': task.quotationAmount,
        'actualCost': task.actualCost,
        'assignedAt': task.assignedAt?.toIso8601String(),
        'startedAt': task.startedAt?.toIso8601String(),
        'createdAt': task.createdAt.toIso8601String(),
        'completedAt': task.completedAt?.toIso8601String(),
        'updatedAt': task.updatedAt?.toIso8601String(),

        // === Payment Information ===
        'paymentStatus': task.paymentStatus, // Pending, Approved, Paid, Rejected
        'paymentMethod': task.paymentMethod, // Wallet, External, Link
        'paymentReference': task.paymentReference,
        'paymentApprovedAt': task.paymentApprovedAt?.toIso8601String(),
        'paymentApprovedBy': task.paymentApprovedBy,

        'tenant': {
          'id': tenant.id,
          'fullName': tenant.fullName,
          'email': tenant.email,
          'phone': tenant.phone,
          'profilePhotoUrl': tenant.profilePhotoUrl,
          'role': tenant.role,
        },

        'artisan': {
          'id': artisan.id,
          'fullName': artisan.fullName,
          'phone': artisan.phone,
          'profilePhotoUrl': artisan.profilePhotoUrl,
          'primarySkill': artisan.primarySkill,
          'rating': artisan.rating,
          'role': tenant.role,
        },

        'assignedBy': assignedByUser != null
            ? {
                'id': assignedByUser.id,
                'fullName': assignedByUser.fullName,
                'role': assignedByUser.role,
                'phone': assignedByUser.phone,
                'profilePhotoUrl': assignedByUser.profilePhotoUrl,
              }
            : null,

        'property': {
          'id': property.id,
          'name': property.name,
          'address': property.address,
          'type': property.type,
        },

        'unit': {'id': unit.id, 'unitNumber': unit.unitNumber},

        'maintenanceRequest': {
          'id': maintenanceRequest.id,
          'title': maintenanceRequest.title,
          'status': maintenanceRequest.status,
        },
      };

      return Response.ok(
        jsonEncode({'task': response, 'message': 'Task details fetched successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get task by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch task details'}));
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
          body: jsonEncode({
            'message': 'Task must be marked as Completed by Artisan before payment can be approved',
          }),
        );
      }

      if (task.paymentStatus == 'Paid') {
        return Response(400, body: jsonEncode({'message': 'Payment already approved'}));
      }

      final amount = task.actualCost ?? 0.0;
      if (amount <= 0) {
        return badRequest('No valid amount to approve');
      }

      MaintenanceTaskModel updatedTask = task;

      final maintenanceRequest = await maintenanceRepository.getRequestById(task.maintenanceRequestId);

      if (paymentMethod == 'wallet') {
        //check available balance
        final balance = await paymentRepository.getPropertyAvailableBalance(task.propertyId);

        if (balance < amount) {
          return badRequest('Insufficient wallet amount');
        }
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

  /// GET /maintenance/tasks/my - Get all tasks assigned to the current artisan
  Future<Response> getMyTasks(Request request) async {
    try {
      final artisanId = request.context['userId'] as String?;
      final userRole = request.context['role'] as String?;

      if (artisanId == null) {
        return unauthorized();
      }

      if (userRole != 'artisan') {
        return Response(403, body: jsonEncode({'message': 'Only artisans can access this endpoint'}));
      }

      // Get all active + pending tasks for this artisan across all properties
      final tasks = await maintenanceRepository.getTasksByArtisan(artisanId);

      // Enrich tasks with property and request details
      final enrichedTasks = await Future.wait(
        tasks.map((task) async {
          final request = await maintenanceRepository.getRequestById(task.maintenanceRequestId);
          final unit = await unitRepository.getUnitById(request.unitId);
          final property = await propertyRepository.getPropertyById(task.propertyId);
          final tenant = await userRepository.getUserById(request.tenantId);

          return {
            ...task.toMap(),

            'propertyName': property.name,
            'tenantName': tenant.fullName,
            'tenantId': tenant.id,
            'unit': unit.unitNumber,
            'unitId': unit.id,

            // 'maintenanceRequest': {
            //   'id': request.id,
            //   'title': request.title,
            //   'description': request.description,
            //   'category': request.category,
            //   'priority': request.priority,
            //   'status': request.status,
            // },
            // 'property': {
            //   'id': property.id,
            //   'name': property.name,
            //   'address': property.address,
            //   'type': property.type,
            // },
            // 'tenant': {
            //   'id': tenant.id,
            //   'fullName': tenant.fullName,
            //   'email': tenant.email,
            //   'phone': tenant.phone,
            //   'profilePhotoUrl': tenant.profilePhotoUrl,
            //   'role': tenant.role,
            // },
          };
        }),
      );

      return Response.ok(
        jsonEncode({
          'tasks': enrichedTasks,
          'totalTasks': enrichedTasks.length,
          'message': 'Tasks fetched successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my tasks error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch your tasks'}));
    }
  }

  Response badRequest(String message) => Response(400, body: jsonEncode({'message': message}));
  Response unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
