import 'package:cloud_firestore/cloud_firestore.dart';
import 'distance_calculator.dart';

/// Model untuk order dengan informasi lokasi
class OrderLocation {
  final String orderId;
  final String address;
  final double latitude;
  final double longitude;
  final String userId;
  final int total;
  final DateTime createdAt;
  final String recipientName;
  
  OrderLocation({
    required this.orderId,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.total,
    required this.createdAt,
    required this.recipientName,
  });
  
  factory OrderLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderLocation(
      orderId: doc.id,
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      total: (data['total'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      recipientName: data['recipientName'] ?? '',
    );
  }
}

/// Service untuk optimasi rute pengiriman
/// Menggunakan Nearest Neighbor Algorithm
class RouteOptimizerService {
  /// Lokasi toko KatsuChip (Padang, Sumatera Barat)
  static const double _storeLat = -0.9059128990717297; // KatsuChip Padang
  static const double _storeLon = 100.36016218288833;
  
  /// Expose store location untuk perhitungan dari luar
  static double get storeLat => _storeLat;
  static double get storeLon => _storeLon;
  
  /// Radius untuk grouping orders (dalam km)
  static const double _groupingRadius = 2.0;
  
  /// Group pending orders berdasarkan kedekatan lokasi
  /// Returns: List of order batches, setiap batch berisi orders yang berdekatan
  static List<List<OrderLocation>> groupNearbyOrders(
    List<OrderLocation> orders,
  ) {
    if (orders.isEmpty) return [];
    
    final List<List<OrderLocation>> batches = [];
    final Set<String> processed = {};
    
    for (final order in orders) {
      if (processed.contains(order.orderId)) continue;
      
      // Start new batch dengan order ini
      final List<OrderLocation> batch = [order];
      processed.add(order.orderId);
      
      // Cari orders lain yang berdekatan dengan orders di batch ini
      for (final other in orders) {
        if (processed.contains(other.orderId)) continue;
        
        // Check jika other berdekatan dengan any order di batch
        bool isNearby = false;
        for (final batchOrder in batch) {
          if (DistanceCalculator.isNearby(
            batchOrder.latitude,
            batchOrder.longitude,
            other.latitude,
            other.longitude,
            radiusKm: _groupingRadius,
          )) {
            isNearby = true;
            break;
          }
        }
        
        if (isNearby) {
          batch.add(other);
          processed.add(other.orderId);
        }
      }
      
      batches.add(batch);
    }
    
    return batches;
  }
  
  /// Optimasi urutan pengiriman dalam 1 batch menggunakan Nearest Neighbor
  /// Mulai dari toko, pilih order terdekat, lalu order terdekat berikutnya, dst
  /// 
  /// Returns: List of orders sorted by optimal delivery sequence
  static List<OrderLocation> optimizeRoute(List<OrderLocation> orders) {
    if (orders.isEmpty) return [];
    if (orders.length == 1) return orders;
    
    final List<OrderLocation> optimized = [];
    final Set<String> visited = {};
    
    // Start from store location
    double currentLat = _storeLat;
    double currentLon = _storeLon;
    
    // Nearest Neighbor algorithm
    while (visited.length < orders.length) {
      OrderLocation? nearest;
      double minDistance = double.infinity;
      
      // Find nearest unvisited order
      for (final order in orders) {
        if (visited.contains(order.orderId)) continue;
        
        final distance = DistanceCalculator.calculateDistance(
          currentLat,
          currentLon,
          order.latitude,
          order.longitude,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearest = order;
        }
      }
      
      if (nearest != null) {
        optimized.add(nearest);
        visited.add(nearest.orderId);
        currentLat = nearest.latitude;
        currentLon = nearest.longitude;
      }
    }
    
    return optimized;
  }
  
  /// Get pending orders dari Firestore dengan koordinat
  static Future<List<OrderLocation>> getPendingOrders() async {
    final db = FirebaseFirestore.instance;
    
    final snapshot = await db
        .collectionGroup('orders')
        .where('status', isEqualTo: 'pending')
        .where('latitude', isGreaterThan: 0) // Hanya orders yang sudah di-geocode
        .get();
    
    return snapshot.docs
        .map((doc) => OrderLocation.fromFirestore(doc))
        .toList();
  }
  
  /// Main function: Group dan optimize semua pending orders
  /// Returns: Map dengan batch ID sebagai key dan optimized orders sebagai value
  static Future<Map<String, List<OrderLocation>>> createOptimalBatches() async {
    // Get all pending orders
    final orders = await getPendingOrders();
    
    if (orders.isEmpty) return {};
    
    // Group nearby orders
    final batches = groupNearbyOrders(orders);
    
    // Optimize each batch
    final Map<String, List<OrderLocation>> optimizedBatches = {};
    for (int i = 0; i < batches.length; i++) {
      final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}_$i';
      optimizedBatches[batchId] = optimizeRoute(batches[i]);
    }
    
    return optimizedBatches;
  }
  
  /// Assign batch ke kurir dan update deliverySequence
  static Future<void> assignBatchToKurir(
    String kurirId,
    String batchId,
    List<OrderLocation> orders,
  ) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    
    for (int i = 0; i < orders.length; i++) {
      final order = orders[i];
      
      // Find document reference (karena collectionGroup, perlu cari parent path)
      final snapshot = await db
          .collectionGroup('orders')
          .where(FieldPath.documentId, isEqualTo: order.orderId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final docRef = snapshot.docs.first.reference;
        
        batch.update(docRef, {
          'kurirId': kurirId,
          'batchId': batchId,
          'deliverySequence': i + 1, // Sequence dimulai dari 1
          'status': 'confirmed', // Update status dari pending ke confirmed
          'assignedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    
    await batch.commit();
  }
  
  /// Hitung estimasi total jarak untuk 1 batch
  static double calculateBatchDistance(List<OrderLocation> orders) {
    if (orders.isEmpty) return 0;
    
    final coordinates = <List<double>>[];
    
    // Start from store
    coordinates.add([_storeLat, _storeLon]);
    
    // Add all order locations
    for (final order in orders) {
      coordinates.add([order.latitude, order.longitude]);
    }
    
    return DistanceCalculator.calculateRouteDistance(coordinates);
  }
}
