import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service untuk geocoding (convert alamat ke lat/lng)
/// Menggunakan Nominatim (OpenStreetMap) - GRATIS, no API key
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  
  /// Convert alamat text ke koordinat (latitude, longitude)
  /// Returns null jika alamat tidak ditemukan
  /// 
  /// Example:
  /// ```dart
  /// final coords = await GeocodingService.getCoordinates('Jl. Sudirman No. 1, Jakarta');
  /// if (coords != null) {
  ///   print('Lat: ${coords['latitude']}, Lng: ${coords['longitude']}');
  /// }
  /// ```
  static Future<Map<String, double>?> getCoordinates(String address) async {
    try {
      // Nominatim requires User-Agent header
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
        'countrycodes': 'id', // Batasi ke Indonesia saja
      });
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'KatsuChipApp/1.0', // Required by Nominatim
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isEmpty) {
          return null;
        }
        
        final location = results[0];
        return {
          'latitude': double.parse(location['lat']),
          'longitude': double.parse(location['lon']),
        };
      }
      
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }
  
  /// Batch geocoding untuk multiple alamat
  /// Returns Map dengan address sebagai key dan coordinates sebagai value
  static Future<Map<String, Map<String, double>?>> batchGeocode(
    List<String> addresses,
  ) async {
    final Map<String, Map<String, double>?> results = {};
    
    for (final address in addresses) {
      // Nominatim rate limit: max 1 request per second
      await Future.delayed(const Duration(seconds: 1));
      results[address] = await getCoordinates(address);
    }
    
    return results;
  }
  
  /// Reverse geocoding: convert lat/lng ke alamat
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
        },
      );
      
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'KatsuChipApp/1.0'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
      
      return null;
    } catch (e) {
      print('Reverse geocoding error: $e');
      return null;
    }
  }
}
