import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class LeasePaymentCalculatorService {
  static Map<String, dynamic> calculate({required LeaseModel lease, required UnitModel unit}) {
    final monthlyRent = unit.monthlyRent;

    final durationMonths = lease.durationMonths ?? 12;

    final totalLeaseRent = monthlyRent * (durationMonths / 12);

    double oneTimeFeeTotal = 0;
    double recurringFeeTotal = 0;

    final oneTimeFees = <Map<String, dynamic>>[];
    final recurringFees = <Map<String, dynamic>>[];

    for (final fee in lease.fees ?? <UnitFee>[]) {
      final amount = fee.isPercentage ? monthlyRent * fee.amount / 100 : fee.amount;

      if (fee.isOneTime) {
        oneTimeFeeTotal += amount;

        oneTimeFees.add({"name": fee.name, "amount": amount});
      } else {
        recurringFeeTotal += amount;

        recurringFees.add({"name": fee.name, "amountPerYear": amount});
      }
    }

    return {
      "monthlyRent": monthlyRent,
      "leaseDurationMonths": durationMonths,
      "totalRentForLease": totalLeaseRent,

      "oneTimeFees": oneTimeFees,
      "recurringFees": recurringFees,

      "firstPayment": {
        "rent": monthlyRent,
        'duration': durationMonths,
        "fees": oneTimeFeeTotal + recurringFeeTotal,
        "total": totalLeaseRent + oneTimeFeeTotal + recurringFeeTotal,
      },

      "renewalPayment": {
        "rent": monthlyRent,
        "fees": recurringFeeTotal,
        "duration": 12,
        "total": monthlyRent + recurringFeeTotal,
      },
    };
  }
}
