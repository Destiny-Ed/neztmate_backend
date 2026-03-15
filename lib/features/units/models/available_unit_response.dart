import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class AvailableUnitResponse {
  final UnitModel unit;
  final PropertyModel property; 
  AvailableUnitResponse(this.unit, this.property);

  Map<String, dynamic> toMap() => {'unit': unit.toMap(), 'property': property.toMap()};
}
