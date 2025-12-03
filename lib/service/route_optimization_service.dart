import 'dart:math';

class RouteOptimizationService {
  /// Hitung jarak antara dua koordinat menggunakan Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // dalam kilometer
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Konversi derajat ke radian
  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Cek apakah dua pesanan searah (dalam radius tertentu, misal 2km)
  static bool isNearby(
    double lat1,
    double lon1,
    double lat2,
    double lon2, {
    double maxDistanceKm = 2.0,
  }) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= maxDistanceKm;
  }

  /// Optimasi rute untuk multiple orders menggunakan algoritma Nearest Neighbor
  /// Returns list of order IDs in optimized sequence
  static List<String> optimizeRoute({
    required List<OrderLocation> orders,
    required double startLat,
    required double startLon,
  }) {
    if (orders.isEmpty) return [];
    if (orders.length == 1) return [orders.first.orderId];

    final List<String> optimizedSequence = [];
    final List<OrderLocation> remaining = List.from(orders);
    
    double currentLat = startLat;
    double currentLon = startLon;

    // Nearest Neighbor Algorithm
    while (remaining.isNotEmpty) {
      OrderLocation? nearest;
      double nearestDistance = double.infinity;

      // Cari order terdekat dari posisi saat ini
      for (final order in remaining) {
        final distance = calculateDistance(
          currentLat,
          currentLon,
          order.latitude,
          order.longitude,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = order;
        }
      }

      if (nearest != null) {
        optimizedSequence.add(nearest.orderId);
        remaining.remove(nearest);
        currentLat = nearest.latitude;
        currentLon = nearest.longitude;
      }
    }

    return optimizedSequence;
  }

  /// Hitung total jarak untuk rute tertentu
  static double calculateTotalDistance({
    required List<OrderLocation> orders,
    required double startLat,
    required double startLon,
  }) {
    if (orders.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double currentLat = startLat;
    double currentLon = startLon;

    for (final order in orders) {
      totalDistance += calculateDistance(
        currentLat,
        currentLon,
        order.latitude,
        order.longitude,
      );
      currentLat = order.latitude;
      currentLon = order.longitude;
    }

    return totalDistance;
  }

  /// Grouping orders yang searah (clustering)
  static List<List<OrderLocation>> clusterNearbyOrders({
    required List<OrderLocation> orders,
    double maxDistanceKm = 2.0,
  }) {
    if (orders.isEmpty) return [];

    final List<List<OrderLocation>> clusters = [];
    final List<OrderLocation> remaining = List.from(orders);

    while (remaining.isNotEmpty) {
      final current = remaining.removeAt(0);
      final List<OrderLocation> cluster = [current];

      // Cari orders lain yang dekat dengan current
      remaining.removeWhere((order) {
        final isClose = isNearby(
          current.latitude,
          current.longitude,
          order.latitude,
          order.longitude,
          maxDistanceKm: maxDistanceKm,
        );
        if (isClose) {
          cluster.add(order);
        }
        return isClose;
      });

      clusters.add(cluster);
    }

    return clusters;
  }
}

/// Model untuk lokasi order
class OrderLocation {
  final String orderId;
  final double latitude;
  final double longitude;
  final String address;

  OrderLocation({
    required this.orderId,
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}
