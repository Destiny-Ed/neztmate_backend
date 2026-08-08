import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class LeasePaymentCalculatorService {
  static Map<String, dynamic> calculate({
    required LeaseModel lease,
    required UnitModel unit,
    int? customDurationMonth,
  }) {
    final monthlyRent = unit.monthlyRent;

    final durationMonths = lease.durationMonths ?? 12;
    final renewalDurationMonths = customDurationMonth ?? (durationMonths < 12 ? durationMonths : 12);

    final totalRentForLease = monthlyRent * durationMonths;
    final totalRentForLeaseRenewal = monthlyRent * renewalDurationMonths;

    double oneTimeFeeTotal = 0.0;
    double recurringFeeTotal = 0.0;

    final oneTimeFees = <Map<String, dynamic>>[];
    final recurringFees = <Map<String, dynamic>>[];

    for (final fee in lease.fees ?? <UnitFee>[]) {
      final feeAmount = fee.isPercentage ? monthlyRent * fee.amount / 100 : fee.amount;

      if (fee.isOneTime) {
        oneTimeFeeTotal += feeAmount;
        oneTimeFees.add({'name': fee.name, 'amount': feeAmount, 'isPercentage': fee.isPercentage});
      } else {
        recurringFeeTotal += feeAmount;
        recurringFees.add({'name': fee.name, 'amount': feeAmount, 'isPercentage': fee.isPercentage});
      }
    }

    return {
      'monthlyRent': monthlyRent,
      'leaseDurationMonths': durationMonths,
      'leaseDurationMonthsRenewal': renewalDurationMonths,
      'totalRentForLease': totalRentForLease,
      'totalRentForLeaseRenewal': totalRentForLeaseRenewal,
      'oneTimeFees': oneTimeFees,
      'recurringFees': recurringFees,
      'firstPayment': {
        'rent': monthlyRent,
        'duration': durationMonths,
        'fees': oneTimeFeeTotal + recurringFeeTotal,
        'total':
            totalRentForLease + (oneTimeFeeTotal * durationMonths) + (recurringFeeTotal * durationMonths),
      },
      'renewalPayment': {
        'rent': monthlyRent,
        'fees': recurringFeeTotal,
        'duration': renewalDurationMonths,
        'total': totalRentForLeaseRenewal + (recurringFeeTotal * renewalDurationMonths),
      },
    };
  }

  /// Calculate for a single unit (used during unit creation/update)
  static Map<String, dynamic> calculateForUnit({required UnitModel unit, required int durationMonths}) {
    final monthlyRent = unit.monthlyRent ?? 0.0;

    final renewalDurationMonths = durationMonths < 12 ? durationMonths : 12;

    final totalRentForLease = monthlyRent * durationMonths;
    final totalRentForLeaseRenewal = monthlyRent * renewalDurationMonths;

    double oneTimeFeeTotal = 0.0;
    double recurringFeeTotal = 0.0;

    final oneTimeFees = <Map<String, dynamic>>[];
    final recurringFees = <Map<String, dynamic>>[];

    for (final fee in unit.fees ?? <UnitFee>[]) {
      final feeAmount = fee.isPercentage ? monthlyRent * fee.amount / 100 : fee.amount;

      if (fee.isOneTime) {
        oneTimeFeeTotal += feeAmount;
        oneTimeFees.add({'name': fee.name, 'amount': feeAmount, 'isPercentage': fee.isPercentage});
      } else {
        recurringFeeTotal += feeAmount;
        recurringFees.add({'name': fee.name, 'amount': feeAmount, 'isPercentage': fee.isPercentage});
      }
    }

    return {
      'monthlyRent': monthlyRent,
      'leaseDurationMonths': durationMonths,
      'leaseDurationMonthsRenewal': renewalDurationMonths,
      'totalRentForLease': totalRentForLease,
      'totalRentForLeaseRenewal': totalRentForLeaseRenewal,
      'oneTimeFees': oneTimeFees,
      'recurringFees': recurringFees,
      'firstPayment': {
        'rent': monthlyRent,
        'duration': durationMonths,
        'fees': oneTimeFeeTotal + recurringFeeTotal,
        'total':
            totalRentForLease + (oneTimeFeeTotal * durationMonths) + (recurringFeeTotal * durationMonths),
      },
      'renewalPayment': {
        'rent': monthlyRent,
        'fees': recurringFeeTotal,
        'duration': renewalDurationMonths,
        'total': totalRentForLeaseRenewal + (recurringFeeTotal * renewalDurationMonths),
      },
    };
  }
}
