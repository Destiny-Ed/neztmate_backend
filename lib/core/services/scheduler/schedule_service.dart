import 'dart:async';

import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/affiliates/repository/affiliate_repository.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/invites/repository/invite_repo.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:neztmate_backend/features/payments/models/payment_disbursement_model.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

class SchedulerService {
  Timer? _hourlyTimer;
  Timer? _dailyTimer;
  Timer? _twelveHourTimer;

  bool _hourlyRunning = false;
  bool _dailyRunning = false;
  bool _twelveHourRunning = false;

  final InviteRepository inviteRepository;
  final LeaseRepository leaseRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;
  final PaymentRepository paymentRepository;
  final AffiliateRepository affiliateRepository;
  final SubscriptionRepository subscriptionRepository;
  final PartnerRepository? partnerRepository;
  final UnitRepository? unitRepository;

  final PaystackService paystackService;

  SchedulerService({
    required this.inviteRepository,
    required this.leaseRepository,
    required this.notificationRepository,
    required this.historyRepository,
    required this.paymentRepository,
    required this.affiliateRepository,
    required this.subscriptionRepository,
    required this.partnerRepository,
    required this.unitRepository,
    PaystackService? paystackService,
  }) : paystackService = paystackService ?? PaystackService();

  void start() {
    // Light / frequent jobs
    // _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) => _runHourlyJobs());

    // Money movement
    _twelveHourTimer = Timer.periodic(const Duration(hours: 12), (_) {
      _runHourlyJobs(); //remove in production
      _runTwelveHourJobs();
    });

    // Heavy daily maintenance
    _dailyTimer = Timer.periodic(const Duration(days: 1), (_) => _runDailyJobs());

    // Optional: run once shortly after boot (don't block start)
    // Future.delayed(const Duration(seconds: 15), () async {
    //   await _runHourlyJobs();
    // });

    print('✅ SchedulerService started (hourly / 12h / daily)');
  }

  void stop() {
    _hourlyTimer?.cancel();
    _twelveHourTimer?.cancel();
    _dailyTimer?.cancel();
    print('🛑 SchedulerService stopped');
  }

  // JOB GROUPS

  Future<void> _runHourlyJobs() async {
    if (_hourlyRunning) return;
    _hourlyRunning = true;
    try {
      await _cleanupExpiredInvites();
      await _sendLeaseDueReminders(withinDays: 5);
      await _sendLeaseOverdueNotices();
    } catch (e, s) {
      print('Hourly jobs error: $e\n$s');
    } finally {
      _hourlyRunning = false;
    }
  }

  Future<void> _runTwelveHourJobs() async {
    if (_twelveHourRunning) return;
    _twelveHourRunning = true;
    try {
      await _processDueDisbursements();
      await _processManagerCommissions();
      await _processAffiliatePayouts();
    } catch (e, s) {
      print('12h money jobs error: $e\n$s');
    } finally {
      _twelveHourRunning = false;
    }
  }

  Future<void> _runDailyJobs() async {
    if (_dailyRunning) return;
    _dailyRunning = true;
    try {
      await _updateExpiredLeases();
      await _checkAndUpdateExpiredSubscriptions();
      await _checkAndUpdateExpiredPartnerSubscriptions();
      await _deactivateInactivePartners();
      // Optional: await _autoListVacantUnitsAfterLeaseEnd();
    } catch (e, s) {
      print('Daily jobs error: $e\n$s');
    } finally {
      _dailyRunning = false;
    }
  }

  // INVITES

  Future<void> _cleanupExpiredInvites() async {
    try {
      // Prefer a bulk method on the repo, e.g. expirePendingOlderThan(days: 5)
      final count = await inviteRepository.expireOverdueInvites();
      if (count > 0) {
        print('🎫 Expired $count invite(s)');
      }
    } catch (e) {
      // Method may not exist yet — fail soft
      print('Invite cleanup skipped/error: $e');
    }
  }

  // LEASES

  Future<void> _updateExpiredLeases() async {
    try {
      final updatedCount = await leaseRepository.updateExpiredLeasesToInactive();
      if (updatedCount > 0) {
        print('📄 Marked $updatedCount lease(s) Inactive');
      }
    } catch (e) {
      print('Error updating expired leases: $e');
    }
  }

  Future<void> _sendLeaseDueReminders({int withinDays = 5}) async {
    try {
      final expiringLeases = await leaseRepository.getExpiringLeases(withinDays: withinDays);

      for (final lease in expiringLeases) {
        final daysLeft = lease.endDate.difference(DateTime.now()).inDays;
        if (daysLeft <= 0) continue;

        // Avoid spam: only remind on day 5, 3, 1 (adjust as needed)
        if (![1, 3, 5].contains(daysLeft)) continue;

        await _notifyBothParties(
          lease: lease,
          type: 'lease_due_soon',
          tenantTitle: 'Lease renewal reminder',
          tenantBody: 'Your lease expires in $daysLeft day(s). Renew or contact your landlord.',
          ownerTitle: 'Tenant lease expiring',
          ownerBody: 'A lease expires in $daysLeft day(s).',
        );
      }
    } catch (e) {
      print('Lease due reminders error: $e');
    }
  }

  Future<void> _sendLeaseOverdueNotices() async {
    try {
      // Active leases whose endDate is already past (if status job lags)
      final overdue = await leaseRepository.getExpiringLeases(withinDays: 0);
      // Or: getLeasesByStatus('Active') filtered client-side if needed

      for (final lease in overdue) {
        if (lease.endDate.isAfter(DateTime.now())) continue;
        if (lease.status.toLowerCase() == 'inactive') continue;

        await _notifyBothParties(
          lease: lease,
          type: 'lease_overdue',
          tenantTitle: 'Lease has expired',
          tenantBody: 'Your lease has expired. Renew or contact your landlord.',
          ownerTitle: 'Lease expired',
          ownerBody: 'A tenant lease has expired and may need action.',
        );
      }
    } catch (e) {
      print('Lease overdue notices error: $e');
    }
  }

  Future<void> _notifyBothParties({
    required LeaseModel lease,
    required String type,
    required String tenantTitle,
    required String tenantBody,
    required String ownerTitle,
    required String ownerBody,
  }) async {
    final now = DateTime.now();

    await notificationRepository.create(
      NotificationModel(
        id: '',
        userId: lease.tenantId,
        partnerId: lease.partnerId,
        type: type,
        title: tenantTitle,
        body: tenantBody,
        relatedId: lease.id,
        relatedCollection: 'leases',
        createdAt: now,
      ),
    );

    await notificationRepository.create(
      NotificationModel(
        id: '',
        userId: lease.landownerId,
        partnerId: lease.partnerId,
        type: type,
        title: ownerTitle,
        body: ownerBody,
        relatedId: lease.id,
        relatedCollection: 'leases',
        createdAt: now,
      ),
    );
  }

  // SUBSCRIPTIONS (landowner plans)

  Future<void> _checkAndUpdateExpiredSubscriptions() async {
    try {
      final expiredSubscriptions = await subscriptionRepository.getExpiredSubscriptions();
      var updatedCount = 0;

      for (final sub in expiredSubscriptions) {
        await subscriptionRepository.updateSubscriptionStatus(sub.id, status: 'expired');

        await notificationRepository.create(
          NotificationModel(
            id: '',
            userId: sub.userId,
            partnerId: sub.partnerId,
            type: 'subscription_expired',
            title: 'Subscription expired',
            body: 'Your plan has expired. Renew to keep premium features.',
            relatedId: sub.id,
            relatedCollection: 'subscriptions',
            createdAt: DateTime.now(),
          ),
        );

        updatedCount++;
      }

      if (updatedCount > 0) {
        print('📦 Expired $updatedCount user subscription(s)');
      }
    } catch (e, stack) {
      print('Subscription expiry check error: $e\n$stack');
    }
  }

  // PARTNER SUBSCRIPTIONS / STATUS
  // (white-label partners billed at partner level)

  Future<void> _checkAndUpdateExpiredPartnerSubscriptions() async {
    if (partnerRepository == null) return;

    try {
      // Preferred: dedicated method on partner or subscription repo
      // e.g. subscriptionRepository.getExpiredPartnerSubscriptions()
      final expired = await subscriptionRepository.getExpiredPartnerSubscriptions();

      for (final sub in expired) {
        await subscriptionRepository.updateSubscriptionStatus(sub.id, status: 'expired');

        // Soft-flag partner features (do not delete data)
        if (sub.partnerId != null && sub.partnerId.isNotEmpty) {
          try {
            final partner = await partnerRepository!.getPartnerById(sub.partnerId);
            // Keep isActive true but mark billing state in fees/features if you store it
            await partnerRepository!.updatePartner(
              partner.copyWith(
                features: {...partner.features, 'subscriptionStatus': 'expired', 'billingPastDue': true},
                updatedAt: DateTime.now(),
              ),
            );

            await partnerRepository!.createPartnerNotification(
              partnerId: partner.id,
              title: 'Partner subscription expired',
              body: 'Your partner plan has expired. Update billing to restore full limits.',
              type: 'partner_billing',
            );
          } catch (e) {
            print('Partner sub update for ${sub.partnerId}: $e');
          }
        }
      }
    } catch (e) {
      // Method may not exist yet
      print('Partner subscription expiry skipped/error: $e');
    }
  }

  Future<void> _deactivateInactivePartners() async {
    if (partnerRepository == null) return;

    try {
      // Partners explicitly marked suspended / inactive by platform stay inactive.
      // Optional: auto-suspend partners with billingPastDue longer than N days.
      final partners = await partnerRepository!.listPartners(activeOnly: false);

      for (final p in partners) {
        final billingPastDue = p.features['billingPastDue'] == true;
        final status = p.features['subscriptionStatus']?.toString();
        final graceDays = 14;
        final updatedAt = p.updatedAt;
        final pastGrace = DateTime.now().difference(updatedAt).inDays >= graceDays;

        if (billingPastDue && status == 'expired' && pastGrace && p.isActive) {
          await partnerRepository!.updatePartner(p.copyWith(isActive: false, updatedAt: DateTime.now()));

          await partnerRepository!.createPartnerNotification(
            partnerId: p.id,
            title: 'Partner suspended',
            body: 'Partner access suspended after billing grace period.',
            type: 'partner_billing',
          );

          print('🚫 Suspended partner ${p.slug} after billing grace');
        }
      }
    } catch (e) {
      print('Partner deactivation check error: $e');
    }
  }

  // PAYOUTS / DISBURSEMENTS / COMMISSIONS

  Future<void> _processAffiliatePayouts() async {
    try {
      final pendingPayouts = await affiliateRepository.getPendingPayouts();
      var processedCount = 0;

      for (final payout in pendingPayouts) {
        final account = await paymentRepository.getDefaultPayoutAccount(payout.affiliateId);

        if (account?.paystackSubaccountId == null) {
          print('Affiliate ${payout.affiliateId}: no payout account — skip');
          continue;
        }

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

          await notificationRepository.create(
            NotificationModel(
              id: '',
              userId: payout.affiliateId,
              partnerId: payout.partnerId,
              type: 'affiliate_payout',
              title: 'Commission paid',
              body: 'Your affiliate payout of ₦${payout.amount.toStringAsFixed(0)} was sent.',
              relatedId: payout.id,
              relatedCollection: 'affiliate_payouts',
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      if (processedCount > 0) {
        print('✅ Processed $processedCount affiliate payout(s)');
      }
    } catch (e) {
      print('Affiliate payout scheduler error: $e');
    }
  }

  Future<void> _processDueDisbursements() async {
    try {
      final dueDisbursements = await paymentRepository.getPendingDisbursements();
      print('📊 ${dueDisbursements.length} disbursement(s) due');

      for (final disbursement in dueDisbursements) {
        await _processSingleDisbursement(disbursement);
      }
    } catch (e, stack) {
      print('❌ Disbursement scheduler error: $e\n$stack');
    }
  }

  Future<void> _processSingleDisbursement(PaymentDisbursementModel disbursement) async {
    try {
      final account = await paymentRepository.getDefaultPayoutAccount(disbursement.recipientId);

      if (account?.paystackSubaccountId == null) {
        await paymentRepository.createWithdrawalAsFallback(disbursement);
        await paymentRepository.markDisbursementAsFailed(
          disbursement.id,
          'No subaccount found - moved to manual withdrawal',
        );
        return;
      }

      final reference = 'disb_${disbursement.id}_${DateTime.now().millisecondsSinceEpoch}';

      final success = await paystackService.transferToSubaccount(
        amount: disbursement.netAmount,
        subaccountId: account!.paystackSubaccountId!,
        reference: reference,
        reason: '${disbursement.recipientType} payout for payment ${disbursement.paymentId}',
      );

      if (success) {
        await paymentRepository.markDisbursementAsCompleted(disbursement.id, reference);
        print('✅ Auto-disbursed ₦${disbursement.netAmount} → ${disbursement.recipientType}');
      } else {
        await paymentRepository.markDisbursementAsFailed(disbursement.id, 'Transfer failed');
      }
    } catch (e) {
      print('Failed disbursement ${disbursement.id}: $e');
      await paymentRepository.markDisbursementAsFailed(disbursement.id, e.toString());
    }
  }

  Future<void> _processManagerCommissions() async {
    try {
      final commissions = await paymentRepository.getManagersCommissions();

      for (final commission in commissions) {
        final account = await paymentRepository.getDefaultPayoutAccount(commission.managerId);
        if (account?.paystackSubaccountId == null) continue;

        final ref = 'comm_${commission.id}_${DateTime.now().millisecondsSinceEpoch}';
        final success = await paystackService.transferToSubaccount(
          amount: commission.commissionAmount,
          subaccountId: account!.paystackSubaccountId!,
          reference: ref,
          reason: 'Manager commission payout',
        );

        if (success) {
          await paymentRepository.markCommissionAsPaid(commission.id, 'auto');
        }
      }
    } catch (e) {
      print('Manager commission scheduler error: $e');
    }
  }
}
