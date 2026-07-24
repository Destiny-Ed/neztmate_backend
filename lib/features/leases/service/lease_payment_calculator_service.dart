import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class LeasePaymentCalculatorService {
  static Map<String, dynamic> calculate({required LeaseModel lease, required UnitModel unit}) {
    final monthlyRent = unit.monthlyRent;

    final durationMonths = lease.durationMonths ?? 12;

    final totalRentForLease = monthlyRent * durationMonths;

    double oneTimeFeeTotal = 0.0;
    double recurringFeeTotal = 0.0;

    final oneTimeFees = <Map<String, dynamic>>[];
    final recurringFees = <Map<String, dynamic>>[];

    for (final fee in lease.fees ?? <UnitFee>[]) {
      final feeAmount = fee.isPercentage ? monthlyRent * fee.amount / 100 : fee.amount;

      if (fee.isOneTime) {
        oneTimeFeeTotal += feeAmount;

        oneTimeFees.add({"name": fee.name, "amount": feeAmount, "isPercentage": fee.isPercentage});
      } else {
        recurringFeeTotal += feeAmount;

        // recurringFees.add({"name": fee.name, "amountPerYear": feeAmount, "isPercentage": fee.isPercentage});

        recurringFees.add({"name": fee.name, "amount": feeAmount, "isPercentage": fee.isPercentage});
      }
    }

    // First Payment (Initial move-in)
    // final firstPaymentTotal = monthlyRent + oneTimeFeeTotal + recurringFeeTotal;

    // Renewal Payment (subsequent years)
    // final renewalPaymentTotal = monthlyRent + recurringFeeTotal;

    return {
      "monthlyRent": monthlyRent,
      "leaseDurationMonths": durationMonths,
      "totalRentForLease": totalRentForLease,

      "oneTimeFees": oneTimeFees,
      "recurringFees": recurringFees,

      "firstPayment": {
        "rent": monthlyRent,
        'duration': durationMonths,
        "fees": oneTimeFeeTotal + recurringFeeTotal,
        "total":
            totalRentForLease + (oneTimeFeeTotal * durationMonths) + (recurringFeeTotal * durationMonths),
      },

      // "firstPayment": {
      //   "rent": monthlyRent,
      //   "oneTimeFees": oneTimeFeeTotal,
      //   "recurringFees": recurringFeeTotal,
      //   "total": firstPaymentTotal,
      // },
      "renewalPayment": {
        "rent": monthlyRent,
        "fees": recurringFeeTotal,
        "duration": durationMonths,
        "total": totalRentForLease + (recurringFeeTotal * totalRentForLease),
      },
      // "renewalPayment": {
      //   "rent": monthlyRent,
      //   "recurringFees": recurringFeeTotal,
      //   "durationMonths": 12,
      //   "total": renewalPaymentTotal,
      // },

      // "summary": {
      //   "totalOneTimeFees": oneTimeFeeTotal,
      //   "totalRecurringFeesPerYear": recurringFeeTotal,
      //   "grandTotalForFullLease":
      //       totalRentForLease + oneTimeFeeTotal + (recurringFeeTotal * (durationMonths / 12)),
      // },
    };
  }

  /// Calculate for a single unit (used during unit creation/update)
  static Map<String, dynamic> calculateForUnit({required UnitModel unit, required int durationMonths}) {
    final monthlyRent = unit.monthlyRent ?? 0.0;

    final totalRentForTerm = monthlyRent * durationMonths;

    double oneTimeFeeTotal = 0.0;
    double recurringFeeTotal = 0.0;

    final oneTimeFees = <Map<String, dynamic>>[];
    final recurringFees = <Map<String, dynamic>>[];

    for (final fee in unit.fees ?? <UnitFee>[]) {
      final feeAmount = fee.isPercentage ? monthlyRent * (fee.amount / 100) : fee.amount;

      if (fee.isOneTime) {
        oneTimeFeeTotal += feeAmount;
        oneTimeFees.add({"name": fee.name, "amountPerMonth": feeAmount, "isPercentage": fee.isPercentage});
      } else {
        recurringFeeTotal += feeAmount;
        recurringFees.add({"name": fee.name, "amountPerMonth": feeAmount, "isPercentage": fee.isPercentage});
      }
    }

    final totalOneTimeFees = oneTimeFeeTotal * durationMonths;
    final totalRecurringFees = recurringFeeTotal * durationMonths;

    final firstPaymentTotal = totalRentForTerm + totalOneTimeFees + totalRecurringFees;
    final renewalPaymentTotal = totalRentForTerm + totalRecurringFees;

    return {
      "monthlyRent": monthlyRent,
      "durationMonths": durationMonths,
      "totalRentForTerm": totalRentForTerm,

      "oneTimeFees": oneTimeFees,
      "recurringFees": recurringFees,

      "firstPayment": {
        "rent": totalRentForTerm,
        "oneTimeFees": oneTimeFeeTotal * durationMonths,
        "recurringFees": recurringFeeTotal * totalRentForTerm,
        "total": firstPaymentTotal,
      },

      "renewalPayment": {
        "rent": totalRentForTerm,
        "recurringFees": recurringFeeTotal,
        "total": renewalPaymentTotal,
      },

      "grandTotalForFullLease":
          totalRentForTerm + oneTimeFeeTotal + (recurringFeeTotal * (durationMonths / 12)),
    };
  }
}
