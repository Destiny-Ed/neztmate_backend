import 'dart:async';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/affiliates/repository/affiliate_repository.dart';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/payments/models/payment_disbursement_model.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';

class SchedulerService {
  // static Timer? _inviteCleanupTimer;
  static Timer? _leaseReminderTimer;
  static Timer? _leaseStatusTimer;
  Timer? _disbursementTimer;

  final InviteRepository inviteRepository;
  final LeaseRepository leaseRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;
  final PaymentRepository paymentRepository;
  final AffiliateRepository affiliateRepository;
  final SubscriptionRepository subscriptionRepository;

  SchedulerService({
    required this.inviteRepository,
    required this.leaseRepository,
    required this.notificationRepository,
    required this.historyRepository,
    required this.paymentRepository,
    required this.affiliateRepository,
    required this.subscriptionRepository,
  });

  final PaystackService paystackService = PaystackService();

  void start() {
    // Clean expired invites every 6 hours
    // _inviteCleanupTimer = Timer.periodic(const Duration(hours: 6), (_) async {
    //   await _cleanupExpiredInvites();
    // });

    _disbursementTimer = Timer.periodic(const Duration(hours: 12), (_) async {
      await _processDueDisbursements();
      await _processManagerCommissions();
      await _processAffiliatePayouts();
    });

    _leaseStatusTimer = Timer.periodic(const Duration(hours: 6), (_) async {
      await _updateExpiredLeases();
      // await _cleanupExpiredInvites();
    });

    // Check lease due dates every day
    _leaseReminderTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      await _sendLeaseDueReminders();

      await _checkAndUpdateExpiredSubscriptions();
    });

    print('✅ SchedulerService started - Lease & Invite maintenance enabled');
  }

  void stop() {
    // _inviteCleanupTimer?.cancel();
    _leaseStatusTimer?.cancel();
    _leaseReminderTimer?.cancel();
    _disbursementTimer?.cancel();
    print('🛑 SchedulerService stopped');
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

  Future<void> _processAffiliatePayouts() async {
    try {
      final pendingPayouts = await affiliateRepository.getPendingPayouts();

      int processedCount = 0;

      for (var payout in pendingPayouts) {
        // Get affiliate's default payout account
        final account = await paymentRepository.getDefaultPayoutAccount(payout.affiliateId);

        if (account?.paystackSubaccountId != null) {
          final ref = 'aff_payout_${payout.id}_${DateTime.now().microsecondsSinceEpoch}';
          final success = await paystackService.transferToSubaccount(
            amount: payout.amount,
            subaccountId: account!.paystackSubaccountId!,
            reference: ref,
            reason: 'Affiliate commission payout',
          );

          if (success) {
            await affiliateRepository.processPayout(payout.id, ref);
            processedCount++;
            print('✅ $processedCount Auto payout processed for affiliate ${payout.affiliateId}');
          }
        }
      }
    } catch (e) {
      print('Auto payout scheduler error: $e');
    }
  }

  Future<void> _checkAndUpdateExpiredSubscriptions() async {
    try {
      final expiredSubscriptions = await subscriptionRepository.getExpiredSubscriptions();

      int updatedCount = 0;

      for (var sub in expiredSubscriptions) {
        await subscriptionRepository.updateSubscriptionStatus(sub.id, status: 'expired');
        updatedCount++;
      }

      print('Updated $updatedCount subscriptions to expired');
    } catch (e, stack) {
      print('Subscription expiry check error: $e\n$stack');
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

  Future<void> _processDueDisbursements() async {
    try {
      final dueDisbursements = await paymentRepository.getPendingDisbursements();

      print('📊 Found ${dueDisbursements.length} disbursements ready for processing');

      for (var disbursement in dueDisbursements) {
        await _processSingleDisbursement(disbursement);
      }
    } catch (e, stack) {
      print('❌ Scheduler error: $e\n$stack');
    }
  }

  Future<void> _processSingleDisbursement(PaymentDisbursementModel disbursement) async {
    try {
      final account = await paymentRepository.getDefaultPayoutAccount(disbursement.recipientId);

      if (account?.paystackSubaccountId == null) {
        // Fallback to manual withdrawal
        await paymentRepository.createWithdrawalAsFallback(disbursement);
        await paymentRepository.markDisbursementAsFailed(
          disbursement.id,
          'No subaccount found - moved to manual withdrawal',
        );
        return;
      }

      final reference = 'disb_${DateTime.now().millisecondsSinceEpoch}';

      final success = await paystackService.transferToSubaccount(
        amount: disbursement.netAmount,
        subaccountId: account!.paystackSubaccountId!,
        reference: reference,
        reason: '${disbursement.recipientType} payout for payment ${disbursement.paymentId}',
      );

      if (success) {
        await paymentRepository.markDisbursementAsCompleted(disbursement.id, reference);
        print('✅ Auto-disbursed ₦${disbursement.netAmount} to ${disbursement.recipientType}');
      } else {
        await paymentRepository.markDisbursementAsFailed(disbursement.id, 'Transfer failed');
      }
    } catch (e) {
      print('Failed to process disbursement ${disbursement.id}: $e');
      await paymentRepository.markDisbursementAsFailed(disbursement.id, e.toString());
    }
  }

  Future<void> _processManagerCommissions() async {
    // Get all pending manager commissions older than 3 days
    final commissions = await paymentRepository.getManagersCommissions();

    for (var commission in commissions) {
      final account = await paymentRepository.getDefaultPayoutAccount(commission.managerId);

      if (account?.paystackSubaccountId != null) {
        final success = await paystackService.transferToSubaccount(
          amount: commission.commissionAmount,
          subaccountId: account!.paystackSubaccountId!,
          reference: 'comm_${DateTime.now().millisecondsSinceEpoch}',
          reason: 'Manager commission payout',
        );

        if (success) {
          await paymentRepository.markCommissionAsPaid(commission.id, 'auto');
        }
      }
    }
  }
}
