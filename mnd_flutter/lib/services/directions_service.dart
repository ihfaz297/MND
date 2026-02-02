import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart';

/// Service for fetching directions from Google Directions API
class DirectionsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetches directions between two addresses and returns polyline points
  ///
  /// [origin] - Starting address (e.g., "Tilagor, Sylhet, Bangladesh")
  /// [destination] - Ending address (e.g., "Ambarkhana, Sylhet, Bangladesh")
  ///
  /// Returns a DirectionsResult containing:
  /// - List of LatLng points for polyline
  /// - Total distance in meters
  /// - Total duration in seconds
  /// - Bounds for camera positioning
  static Future<DirectionsResult?> getDirections({
    required String origin,
    required String destination,
  }) async {
    final url = Uri.parse(
      '$_baseUrl?origin=${Uri.encodeComponent(origin)}'
      '&destination=${Uri.encodeComponent(destination)}'
      '&mode=driving'
      '&key=${ApiConfig.googleMapsApiKey}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        print('Directions API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        print('Directions API status: ${data['status']}');
        return null;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      // Decode polyline
      final polylinePoints =
          _decodePolyline(route['overview_polyline']['points']);

      // Extract bounds
      final bounds = route['bounds'];
      final northeast = LatLng(
        bounds['northeast']['lat'].toDouble(),
        bounds['northeast']['lng'].toDouble(),
      );
      final southwest = LatLng(
        bounds['southwest']['lat'].toDouble(),
        bounds['southwest']['lng'].toDouble(),
      );

      return DirectionsResult(
        polylinePoints: polylinePoints,
        distanceMeters: leg['distance']['value'],
        distanceText: leg['distance']['text'],
        durationSeconds: leg['duration']['value'],
        durationText: leg['duration']['text'],
        startLocation: LatLng(
          leg['start_location']['lat'].toDouble(),
          leg['start_location']['lng'].toDouble(),
        ),
        endLocation: LatLng(
          leg['end_location']['lat'].toDouble(),
          leg['end_location']['lng'].toDouble(),
        ),
        bounds: LatLngBounds(southwest: southwest, northeast: northeast),
      );
    } catch (e) {
      print('Directions API exception: $e');
      return null;
    }
  }

  /// Decodes Google's encoded polyline format into LatLng points
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

/// Data class containing directions result
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final LatLng startLocation;
  final LatLng endLocation;
  final LatLngBounds bounds;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.startLocation,
    required this.endLocation,
    required this.bounds,
  });
}
