import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class LeasePaymentCalculatorService {
  /// Calculates first-term and renewal payment breakdown.
  ///
  /// Renewal uses [lease.pendingRenewalTerms] when present (approved rent/fee
  /// adjustment for next term). Otherwise falls back to current lease/unit fees.
  static Future<Map<String, dynamic>> calculateForLease({
    required LeaseModel lease,
    required UnitModel unit,
    int? customDurationMonth,
  }) async {
    final durationMonths = lease.durationMonths ?? 12;
    final renewalDurationMonths = customDurationMonth ?? (durationMonths < 12 ? durationMonths : 12);

    // ── Current term (always live lease / unit — never pending terms) ──
    final currentMonthlyRent = _resolveMonthlyRent(
      pendingRent: null,
      leaseRent: lease.monthlyRent,
      unitRent: unit.monthlyRent,
    );

    final currentFees = List<UnitFee>.from(lease.fees ?? unit.fees ?? <UnitFee>[]);

    final first = _buildTermBreakdown(
      monthlyRent: currentMonthlyRent,
      durationMonths: durationMonths,
      fees: currentFees,
      includeOneTimeFees: true,
    );

    // ── Renewal term (pending terms if tenant accepted an adjustment) ──
    final pending = lease.pendingRenewalTerms;
    final usesPendingTerms = pending != null && pending.isNotEmpty;

    final renewalMonthlyRent = _resolveMonthlyRent(
      pendingRent: (pending?['monthlyRent'] as num?)?.toDouble(),
      leaseRent: lease.monthlyRent,
      unitRent: unit.monthlyRent,
    );

    final renewalFees = usesPendingTerms ? _feesFromPending(pending) : List<UnitFee>.from(currentFees);

    // One-time fees on renewal only if pending explicitly includes them
    final includeOneTimeOnRenewal = usesPendingTerms ? renewalFees.any((f) => f.isOneTime) : false;

    final renewal = _buildTermBreakdown(
      monthlyRent: renewalMonthlyRent,
      durationMonths: renewalDurationMonths,
      fees: renewalFees,
      includeOneTimeFees: includeOneTimeOnRenewal,
    );

    return {
      'monthlyRent': currentMonthlyRent,
      'leaseDurationMonths': durationMonths,
      'leaseDurationMonthsRenewal': renewalDurationMonths,
      'totalRentForLease': first.rentForTerm,
      'totalRentForLeaseRenewal': renewal.rentForTerm,
      'oneTimeFees': first.oneTimeFeeMaps,
      'recurringFees': first.recurringFeeMaps,
      'usesPendingTerms': usesPendingTerms,
      'firstPayment': {
        'rent': currentMonthlyRent,
        'duration': durationMonths,
        'fees': first.feesTotal,
        'total': first.total,
      },
      'renewalPayment': {
        'rent': renewalMonthlyRent,
        'fees': renewal.feesTotal,
        'duration': renewalDurationMonths,
        'total': renewal.total,
        // helpful for UI / confirm amount
        'oneTimeFees': renewal.oneTimeFeeMaps,
        'recurringFees': renewal.recurringFeeMaps,
      },
      if (usesPendingTerms) 'pendingRenewalTerms': pending,
    };
  }

  /// Calculate for a single unit (used during unit creation/update).
  /// No pending renewal terms — unit is not bound to a lease yet.
  static Map<String, dynamic> calculateForUnit({required UnitModel unit, required int durationMonths}) {
    final monthlyRent = unit.monthlyRent ?? 0.0;
    final renewalDurationMonths = durationMonths < 12 ? durationMonths : 12;
    final fees = List<UnitFee>.from(unit.fees ?? <UnitFee>[]);

    final first = _buildTermBreakdown(
      monthlyRent: monthlyRent,
      durationMonths: durationMonths,
      fees: fees,
      includeOneTimeFees: true,
    );

    // Preview only: same unit fees, recurring only on renewal
    final renewal = _buildTermBreakdown(
      monthlyRent: monthlyRent,
      durationMonths: renewalDurationMonths,
      fees: fees,
      includeOneTimeFees: false,
    );

    return {
      'monthlyRent': monthlyRent,
      'leaseDurationMonths': durationMonths,
      'leaseDurationMonthsRenewal': renewalDurationMonths,
      'totalRentForLease': first.rentForTerm,
      'totalRentForLeaseRenewal': renewal.rentForTerm,
      'oneTimeFees': first.oneTimeFeeMaps,
      'recurringFees': first.recurringFeeMaps,
      'usesPendingTerms': false,
      'firstPayment': {
        'rent': monthlyRent,
        'duration': durationMonths,
        'fees': first.feesTotal,
        'total': first.total,
      },
      'renewalPayment': {
        'rent': monthlyRent,
        'fees': renewal.feesTotal,
        'duration': renewalDurationMonths,
        'total': renewal.total,
        'oneTimeFees': renewal.oneTimeFeeMaps,
        'recurringFees': renewal.recurringFeeMaps,
      },
    };
  }

  static double _resolveMonthlyRent({double? pendingRent, double? leaseRent, double? unitRent}) {
    if (pendingRent != null && pendingRent > 0) return pendingRent;
    if (leaseRent != null && leaseRent > 0) return leaseRent;
    if (unitRent != null && unitRent > 0) return unitRent;
    return 0;
  }

  static List<UnitFee> _feesFromPending(Map<String, dynamic> pending) {
    List<UnitFee> from(dynamic raw) {
      if (raw is! List) return [];
      return raw.map((e) => UnitFee.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }

    final all = from(pending['fees']);
    if (all.isNotEmpty) return all;

    return [...from(pending['recurringFees']), ...from(pending['oneTimeFees'])];
  }

  static _TermBreakdown _buildTermBreakdown({
    required double monthlyRent,
    required int durationMonths,
    required List<UnitFee> fees,
    required bool includeOneTimeFees,
  }) {
    final rentForTerm = monthlyRent * durationMonths;

    double oneTimeFeeTotal = 0.0;
    double recurringFeeMonthly = 0.0;

    final oneTimeFeeMaps = <Map<String, dynamic>>[];
    final recurringFeeMaps = <Map<String, dynamic>>[];

    for (final fee in fees) {
      final feeAmount = fee.isPercentage ? monthlyRent * fee.amount / 100 : fee.amount;

      if (fee.isOneTime) {
        if (!includeOneTimeFees) continue;
        oneTimeFeeTotal += feeAmount;
        oneTimeFeeMaps.add({
          'name': fee.name,
          'amount': feeAmount,
          'isPercentage': fee.isPercentage,
          'isOneTime': true,
        });
      } else {
        recurringFeeMonthly += feeAmount;
        recurringFeeMaps.add({
          'name': fee.name,
          'amount': feeAmount,
          'isPercentage': fee.isPercentage,
          'isOneTime': false,
        });
      }
    }

    // One-time: charged once for the term
    // Recurring: charged per month × duration
    final feesTotal = oneTimeFeeTotal + (recurringFeeMonthly * durationMonths);
    final total = rentForTerm + feesTotal;

    return _TermBreakdown(
      rentForTerm: rentForTerm,
      feesTotal: feesTotal,
      total: total,
      oneTimeFeeMaps: oneTimeFeeMaps,
      recurringFeeMaps: recurringFeeMaps,
    );
  }
}

class _TermBreakdown {
  final double rentForTerm;
  final double feesTotal;
  final double total;
  final List<Map<String, dynamic>> oneTimeFeeMaps;
  final List<Map<String, dynamic>> recurringFeeMaps;

  const _TermBreakdown({
    required this.rentForTerm,
    required this.feesTotal,
    required this.total,
    required this.oneTimeFeeMaps,
    required this.recurringFeeMaps,
  });
}
