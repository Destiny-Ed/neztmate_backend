import 'dart:convert';
import 'package:neztmate_backend/features/location/data/nigeria_locations.dart';
import 'package:shelf/shelf.dart';

class LocationHandler {
  Future<Response> getStates(Request request) async {
    return Response.ok(
      jsonEncode({'states': NigeriaLocations.states}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> getCities(Request request) async {
    final state = (request.url.queryParameters['state'] ?? '').trim();
    if (state.isEmpty) {
      return Response(
        400,
        body: jsonEncode({'message': 'state query param is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final cities = NigeriaLocations.citiesFor(state);
    return Response.ok(
      jsonEncode({'state': state, 'cities': cities}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
