import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class LeasePaymentCalculatorService {
  static Map<String, dynamic> calculate({required LeaseModel lease, required UnitModel unit}) {
    final yearlyRent = unit.yearlyRent;

    final durationMonths = lease.durationMonths ?? 12;

    final totalLeaseRent = yearlyRent * (durationMonths / 12);

    double oneTimeFeeTotal = 0;
    double recurringFeeTotal = 0;

    final oneTimeFees = <Map<String, dynamic>>[];
    final recurringFees = <Map<String, dynamic>>[];

    for (final fee in lease.fees ?? <UnitFee>[]) {
      final amount = fee.isPercentage ? yearlyRent * fee.amount / 100 : fee.amount;

      if (fee.isOneTime) {
        oneTimeFeeTotal += amount;

        oneTimeFees.add({"name": fee.name, "amount": amount});
      } else {
        recurringFeeTotal += amount;

        recurringFees.add({"name": fee.name, "amountPerYear": amount});
      }
    }

    return {
      "yearlyRent": yearlyRent,
      "leaseDurationMonths": durationMonths,
      "totalRentForLease": totalLeaseRent,

      "oneTimeFees": oneTimeFees,
      "recurringFees": recurringFees,

      "firstPayment": {
        "rent": yearlyRent,
        'duration': durationMonths,
        "fees": oneTimeFeeTotal + recurringFeeTotal,
        "total": totalLeaseRent + oneTimeFeeTotal + recurringFeeTotal,
      },

      "renewalPayment": {
        "rent": yearlyRent,
        "fees": recurringFeeTotal,
        "duration": 12,
        "total": yearlyRent + recurringFeeTotal,
      },
    };
  }
}
