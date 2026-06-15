// lib/core/scheduler/scheduler_service.dart
import 'dart:async';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';

class SchedulerService {
  // static Timer? _inviteCleanupTimer;
  static Timer? _leaseReminderTimer;
  static Timer? _leaseStatusTimer;

  final InviteRepository inviteRepository;
  final LeaseRepository leaseRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;

  SchedulerService({
    required this.inviteRepository,
    required this.leaseRepository,
    required this.notificationRepository,
    required this.historyRepository,
  });

  void start() {
    // Clean expired invites every 6 hours
    // _inviteCleanupTimer = Timer.periodic(const Duration(hours: 6), (_) async {
    //   await _cleanupExpiredInvites();
    // });

    _leaseStatusTimer = Timer.periodic(const Duration(hours: 6), (_) async {
      await _updateExpiredLeases();
      // await _cleanupExpiredInvites();
    });

    // Check lease due dates every day
    _leaseReminderTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      await _sendLeaseDueReminders();
    });

    print('✅ SchedulerService started - Lease & Invite maintenance enabled');
  }

  void stop() {
    // _inviteCleanupTimer?.cancel();
    _leaseStatusTimer?.cancel();
    _leaseReminderTimer?.cancel();
  }

  Future<void> _updateExpiredLeases() async {
    try {
      final updatedCount = await leaseRepository.updateExpiredLeasesToInactive();

      if (updatedCount > 0) {
        print('Automatically updated $updatedCount leases to Inactive');
      }
    } catch (e) {
      print('Error in lease status update job: $e');
    }
  }

  // INVITE CLEANUP
  // Future<void> _cleanupExpiredInvites() async {
  //   try {
  //     print('Running expired invites cleanup...');
  //     // You can implement bulk cleanup in repository if needed
  //     // For now, placeholder
  //     print('Expired invites cleanup completed');
  //   } catch (e) {
  //     print('Error cleaning expired invites: $e');
  //   }
  // }

  // LEASE DUE REMINDERS
  Future<void> _sendLeaseDueReminders() async {
    final expiringLeases = await leaseRepository.getExpiringLeases(withinDays: 5);

    for (var lease in expiringLeases) {
      final daysLeft = lease.endDate.difference(DateTime.now()).inDays;

      if (daysLeft > 0) {
        // Send reminder to tenant and landowner
        await notificationRepository.create(
          NotificationModel(
            userId: lease.tenantId,
            type: 'lease_due_soon',
            title: 'Lease Renewal Reminder',
            body: 'Your lease expires in $daysLeft days.',
            relatedId: lease.id,
            relatedCollection: 'leases',
            createdAt: DateTime.now(),
            id: '',
          ),
        );

        await notificationRepository.create(
          NotificationModel(
            userId: lease.landownerId,
            type: 'lease_due_soon',
            title: 'Tenant Lease Expiring',
            body: 'A lease expires in $daysLeft days.',
            relatedId: lease.id,
            relatedCollection: 'leases',
            createdAt: DateTime.now(),
            id: '',
          ),
        );
      }
    }
  }
  // Future<void> _sendLeaseDueReminders() async {
  //   try {
  //     print('Checking for lease due reminders...');

  //     final now = DateTime.now();
  //     final fiveDaysLater = now.add(const Duration(days: 5));

  //     final activeLeases = await leaseRepository.getAllActiveLeases(); // You'll need to add this

  //     for (var lease in activeLeases) {
  //       final daysUntilDue = lease.endDate.difference(now).inDays;

  //       if (daysUntilDue <= 5 && daysUntilDue > 0) {
  //         // 5 days reminder
  //         await _sendLeaseReminder(lease, daysUntilDue);
  //       } else if (daysUntilDue <= 0) {
  //         // Lease is due or overdue
  //         await _sendLeaseOverdueReminder(lease);
  //       }
  //     }
  //   } catch (e) {
  //     print('Error sending lease reminders: $e');
  //   }
  // }

  Future<void> _sendLeaseReminder(LeaseModel lease, int daysLeft) async {
    // Notify Tenant
    await notificationRepository.create(
      NotificationModel(
        userId: lease.tenantId,
        type: 'lease_due_soon',
        title: 'Lease Renewal Reminder',
        body: 'Your lease ends in $daysLeft days. Please renew soon.',
        relatedId: lease.id,
        relatedCollection: 'leases',
        createdAt: DateTime.now(),
        id: '',
      ),
    );

    // Notify Landowner/Manager
    await notificationRepository.create(
      NotificationModel(
        userId: lease.landownerId,
        type: 'lease_due_soon',
        title: 'Tenant Lease Expiring Soon',
        body: 'Tenant lease for unit ends in $daysLeft days.',
        relatedId: lease.id,
        relatedCollection: 'leases',
        createdAt: DateTime.now(),
        id: '',
      ),
    );
  }

  Future<void> _sendLeaseOverdueReminder(LeaseModel lease) async {
    await notificationRepository.create(
      NotificationModel(
        userId: lease.tenantId,
        type: 'lease_overdue',
        title: 'Lease Has Expired',
        body: 'Your lease has expired. Please renew immediately or contact your landlord.',
        relatedId: lease.id,
        relatedCollection: 'leases',
        createdAt: DateTime.now(),
        id: '',
      ),
    );

    await notificationRepository.create(
      NotificationModel(
        userId: lease.landownerId,
        type: 'lease_overdue',
        title: 'Lease Expired',
        body: 'A tenant lease has expired.',
        relatedId: lease.id,
        relatedCollection: 'leases',
        createdAt: DateTime.now(),
        id: '',
      ),
    );
  }
}
