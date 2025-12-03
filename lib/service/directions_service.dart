import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/maps_config.dart';

/// Service untuk mendapatkan directions (polyline) dari Google Directions API
class DirectionsService {
  /// Decode polyline dari Google (encoded string → list of LatLng)
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Dapatkan rute (polyline) dari Google Directions API
  /// 
  /// Params:
  /// - origin: koordinat awal (LatLng)
  /// - destination: koordinat tujuan akhir (LatLng)
  /// - waypoints: list koordinat waypoint di tengah (opsional)
  /// 
  /// Returns: List<LatLng> untuk polyline, atau null jika gagal
  static Future<List<LatLng>?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    // Jika API key kosong, return null (fallback ke straight line)
    if (MapsConfig.googleMapsApiKey.isEmpty) {
      print('⚠️ Google Maps API key tidak diset, tidak bisa fetch directions');
      return null;
    }

    try {
      final originStr = '${origin.latitude},${origin.longitude}';
      final destStr = '${destination.latitude},${destination.longitude}';
      
      // Build waypoints string
      String waypointsStr = '';
      if (waypoints != null && waypoints.isNotEmpty) {
        waypointsStr = waypoints
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');
      }

      final params = {
        'origin': originStr,
        'destination': destStr,
        'key': MapsConfig.googleMapsApiKey,
        'mode': 'driving',
      };

      if (waypointsStr.isNotEmpty) {
        params['waypoints'] = 'optimize:false|$waypointsStr';
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK') {
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes[0] as Map<String, dynamic>;
            final polyline = route['overview_polyline'] as Map<String, dynamic>?;
            final points = polyline?['points'] as String?;

            if (points != null) {
              return decodePolyline(points);
            }
          }
        } else {
          print('⚠️ Directions API error: $status');
        }
      } else {
        print('⚠️ HTTP error: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('❌ Error fetching directions: $e');
      return null;
    }
  }

  /// Fallback: Buat polyline lurus antar titik (jika Directions API gagal)
  static List<LatLng> createStraightLines({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) {
    final points = <LatLng>[origin];
    if (waypoints != null) {
      points.addAll(waypoints);
    }
    points.add(destination);
    return points;
  }
}
