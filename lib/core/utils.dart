import 'package:neztmate_backend/core/di/injector.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';

Future<({bool enabled, double amount})> getCurrentApplicationFee(String partnerId) async {
  final partnerRepository = injector<PartnerRepository>();
  final partner = await partnerRepository.getPartnerById(partnerId);
  if (partner == null) return (enabled: false, amount: 0.0);

  final enabled = partner.fees['applicationFeeEnabled'] == true;
  final amount = (partner.fees['applicationFeeAmount'] as num?)?.toDouble() ?? 0.0;
  if (!enabled || amount <= 0) return (enabled: false, amount: 0.0);
  return (enabled: true, amount: amount);
}
