import 'dart:math';

/// Service untuk menghitung jarak antar koordinat
/// Menggunakan Haversine Formula untuk akurasi tinggi
class DistanceCalculator {
  static const double _earthRadiusKm = 6371.0;
  
  /// Hitung jarak antara 2 koordinat dalam kilometer
  /// Menggunakan Haversine formula
  /// 
  /// Parameters:
  /// - lat1, lon1: koordinat titik pertama
  /// - lat2, lon2: koordinat titik kedua
  /// 
  /// Returns: jarak dalam kilometer
  /// 
  /// Example:
  /// ```dart
  /// final distance = DistanceCalculator.calculateDistance(
  ///   -6.2088, 106.8456, // Jakarta
  ///   -6.9175, 107.6191, // Bandung
  /// );
  /// print('Jarak: ${distance.toStringAsFixed(2)} km');
  /// ```
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Convert degrees to radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);
    
    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1Rad) * cos(lat2Rad);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return _earthRadiusKm * c;
  }
  
  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
  
  /// Hitung jarak dalam meter
  static double calculateDistanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2) * 1000;
  }
  
  /// Check apakah 2 lokasi berdekatan (dalam radius tertentu)
  /// 
  /// Parameters:
  /// - radiusKm: radius maksimal dalam kilometer (default: 2 km)
  /// 
  /// Returns: true jika jarak <= radiusKm
  static bool isNearby(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    double radiusKm = 2.0,
  }) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= radiusKm;
  }
  
  /// Format jarak ke string yang human-readable
  /// 
  /// Example:
  /// - < 1 km: "500 m"
  /// - >= 1 km: "2.5 km"
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }
  
  /// Hitung total jarak untuk route dengan multiple waypoints
  /// 
  /// Parameters:
  /// - coordinates: List of [latitude, longitude] pairs
  /// 
  /// Returns: total jarak dalam kilometer
  /// 
  /// Example:
  /// ```dart
  /// final totalDistance = DistanceCalculator.calculateRouteDistance([
  ///   [-6.2088, 106.8456], // Point A
  ///   [-6.2000, 106.8500], // Point B
  ///   [-6.1950, 106.8550], // Point C
  /// ]);
  /// ```
  static double calculateRouteDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      final current = coordinates[i];
      final next = coordinates[i + 1];
      
      totalDistance += calculateDistance(
        current[0],
        current[1],
        next[0],
        next[1],
      );
    }
    
    return totalDistance;
  }
}
