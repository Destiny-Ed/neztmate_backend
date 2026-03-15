import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class OwnerUnitResponse {
  final UnitModel unit;
  final User? currentTenant; // null if vacant
  final List<HistoryEntryModel> occupantHistory;

  OwnerUnitResponse(this.unit, this.currentTenant, this.occupantHistory);

  Map<String, dynamic> toMap() => {
    'unit': unit.toMap(),
    'currentTenant': currentTenant?.toMap(),
    'occupantHistory': occupantHistory.map((h) => h.toMap()).toList(),
  };
}
