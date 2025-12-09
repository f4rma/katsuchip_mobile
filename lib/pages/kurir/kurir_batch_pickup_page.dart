import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../service/auth_service.dart';
import '../../service/route_optimizer_service.dart';
import '../../service/distance_calculator.dart';
import '../../models/courier_models.dart';
import 'batch_route_map_page.dart';

/// Model untuk batch pesanan
class OrderBatch {
  final String id;
  final List<OrderLocation> orders;
  final double totalDistance; // km
  final int estimatedTime; // minutes

  OrderBatch({
    required this.id,
    required this.orders,
    required this.totalDistance,
    required this.estimatedTime,
  });
}

/// Halaman Batch Pickup dengan Route Optimization
/// Menampilkan rute optimal dari pesanan yang sedang aktif (on_delivery)
class KurirBatchPickupPage extends StatefulWidget {
  final List<CourierOrder>? activeOrders; // Pesanan aktif kurir (opsional)
  
  const KurirBatchPickupPage({
    super.key,
    this.activeOrders,
  });

  @override
  State<KurirBatchPickupPage> createState() => _KurirBatchPickupPageState();
}

class _KurirBatchPickupPageState extends State<KurirBatchPickupPage> {
  bool _isLoading = true;
  List<OrderBatch> _batches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Jika ada activeOrders (dari FAB), langsung optimasi rute dari pesanan tersebut
      if (widget.activeOrders != null && widget.activeOrders!.isNotEmpty) {
        print('?? DEBUG: Processing ${widget.activeOrders!.length} active orders');
        
        // Debug: print koordinat setiap order
        for (final order in widget.activeOrders!) {
          print('  Order ${order.code}: lat=${order.latitude}, lng=${order.longitude}');
        }
        
        final optimizedOrders = widget.activeOrders!
            .where((o) => o.latitude != null && o.longitude != null)
            .map((order) => OrderLocation(
                  orderId: order.orderId,
                  userId: order.userId,
                  address: order.address,
                  latitude: order.latitude!,
                  longitude: order.longitude!,
                  total: order.total.toInt(),
                  createdAt: order.createdAt,
                  recipientName: order.recipientName,
                ))
            .toList();

        print('  ? Valid orders with coordinates: ${optimizedOrders.length}');

        if (optimizedOrders.isEmpty) {
          // Tampilkan dialog dengan informasi lebih detail
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Koordinat Tidak Valid'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pesanan tidak memiliki koordinat pengiriman yang valid.'),
                    const SizedBox(height: 12),
                    const Text('Detail:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...widget.activeOrders!.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${o.code}: ${o.latitude != null && o.longitude != null ? "?" : "?"} (${o.address})',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    )),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          
          setState(() {
            _error = 'Tidak ada pesanan dengan koordinat valid (${widget.activeOrders!.length} pesanan tanpa lat/lng)';
            _isLoading = false;
          });
          return;
        }

        // Optimasi rute
        final route = RouteOptimizerService.optimizeRoute(optimizedOrders);
        
        // Hitung total distance dengan faktor koreksi untuk jarak jalan sebenarnya
        double totalDistance = 0;
        double currentLat = RouteOptimizerService.storeLat;
        double currentLng = RouteOptimizerService.storeLon;
        
        print('?? Calculating route distance:');
        print('   Start: ($currentLat, $currentLng)');
        
        for (int i = 0; i < route.length; i++) {
          final order = route[i];
          final distance = DistanceCalculator.calculateDistance(
            currentLat,
            currentLng,
            order.latitude,
            order.longitude,
          );
          
          print('   Stop ${i + 1}: (${order.latitude}, ${order.longitude}) - ${distance.toStringAsFixed(2)} km');
          
          totalDistance += distance;
          currentLat = order.latitude;
          currentLng = order.longitude;
        }
        
        // Tambahkan faktor koreksi 1.3 untuk jarak jalan sebenarnya
        totalDistance = totalDistance * 1.3;
        
        print('   ?? Total distance (with road factor): ${totalDistance.toStringAsFixed(2)} km');
        
        // Estimasi waktu realistis untuk pengiriman dalam kota
        final estimatedTime = _estimateTime(totalDistance, route.length);
        
        print('   ?? Estimated time: $estimatedTime min');

        setState(() {
          _batches = [
            OrderBatch(
              id: 'batch_delivery',
              orders: route,
              totalDistance: totalDistance,
              estimatedTime: estimatedTime,
            ),
          ];
          _isLoading = false;
        });
        return;
      }

      // Fallback: load dari Firestore (pesanan waiting_pickup)
      // Ambil semua pesanan yang waiting_pickup
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('status', isEqualTo: 'delivering')
          .where('deliveryStatus', isEqualTo: 'waiting_pickup')
          .where('latitude', isGreaterThan: 0) // Harus punya koordinat
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _batches = [];
          _isLoading = false;
        });
        return;
      }

      // Convert ke OrderLocation
      final orders = snapshot.docs.map((doc) {
        final data = doc.data();
        return OrderLocation(
          orderId: doc.id,
          address: data['address'] ?? '',
          latitude: (data['latitude'] ?? 0).toDouble(),
          longitude: (data['longitude'] ?? 0).toDouble(),
          userId: data['userId'] ?? '',
          total: (data['total'] ?? 0) as int,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          recipientName: data['recipientName'] ?? '',
        );
      }).toList();

      print('?? Total orders waiting_pickup: ${orders.length}');

      // Group nearby orders (dalam radius 2km)
      final groupedBatches = RouteOptimizerService.groupNearbyOrders(orders);
      print('??? Grouped into ${groupedBatches.length} batches');

      // Optimize each batch dan convert ke OrderBatch
      final List<OrderBatch> batches = [];
      for (int i = 0; i < groupedBatches.length; i++) {
        final group = groupedBatches[i];
        final optimized = RouteOptimizerService.optimizeRoute(group);
        final distance = RouteOptimizerService.calculateBatchDistance(optimized);

        print('  Batch ${i + 1}: ${optimized.length} orders, ${distance.toStringAsFixed(2)} km');

        batches.add(OrderBatch(
          id: 'BATCH_${i + 1}',
          orders: optimized,
          totalDistance: distance,
          estimatedTime: _estimateTime(distance, optimized.length),
        ));
      }

      // Sort batches by distance (paling dekat dulu)
      batches.sort((a, b) => a.totalDistance.compareTo(b.totalDistance));

      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      print('? Error loading batches: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _estimateTime(double distanceKm, int orderCount) {
    // Asumsi: 30 km/jam + 5 menit per order untuk handling
    final travelMinutes = (distanceKm / 30 * 60).round();
    final handlingMinutes = orderCount * 5;
    return travelMinutes + handlingMinutes;
  }

  Future<void> _openBatchInMaps(OrderBatch batch) async {
    try {
      // Helper validasi koordinat
      bool isValid(double? lat, double? lng) {
        if (lat == null || lng == null) return false;
        if (lat == 0 && lng == 0) return false;
        if (lat < -90 || lat > 90) return false;
        if (lng < -180 || lng > 180) return false;
        return true;
      }

      // Filter orders dengan koordinat valid
      final validOrders = batch.orders
          .where((o) => isValid(o.latitude, o.longitude))
          .toList();

      if (validOrders.isEmpty) {
        throw 'Tidak ada koordinat valid untuk rute.';
      }

      // Jika hanya satu titik, buka destinasi langsung
      if (validOrders.length == 1) {
        final single = validOrders.first;
        final destUrl = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${single.latitude},${single.longitude}&travelmode=driving');
        if (await canLaunchUrl(destUrl)) {
          await launchUrl(destUrl, mode: LaunchMode.externalApplication);
        } else {
          // Fallback search
            final searchUrl = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${single.latitude},${single.longitude}');
            if (await canLaunchUrl(searchUrl)) {
              await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
            } else {
              throw 'Tidak dapat membuka Google Maps';
            }
        }
        return;
      }

      // Bangun waypoints
      final waypointStrings = validOrders
          .map((o) => '${o.latitude},${o.longitude}')
          .toList();

      // Batasi waypoint maksimum (Google URL informal batas ~23). Jika melebihi, kita potong.
      const maxWaypoints = 23; // termasuk destinasi terakhir
      if (waypointStrings.length > maxWaypoints) {
        print('? Terlalu banyak titik (${waypointStrings.length}), dipotong ke $maxWaypoints');
        waypointStrings.removeRange(maxWaypoints, waypointStrings.length);
      }

      // Origin biarkan current location (lebih natural untuk kurir). Destination = titik terakhir setelah optimasi.
      final destination = waypointStrings.last;
      final middle = waypointStrings.sublist(0, waypointStrings.length - 1);

      final directionsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$destination'
        '&waypoints=${middle.join('|')}'
        '&travelmode=driving',
      );

      print('??? Opening batch maps: $directionsUrl');

      if (await canLaunchUrl(directionsUrl)) {
        await launchUrl(directionsUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: buka multi-pin via pencarian terpisah
        final searchQueries = middle.take(5).map((e) => '&query=$e').join();
        final searchUrl = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$destination$searchQueries');
        print('? Directions gagal, mencoba search fallback: $searchUrl');
        if (await canLaunchUrl(searchUrl)) {
          await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
        } else {
          throw 'Tidak dapat membuka Google Maps';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickupBatch(OrderBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pickup'),
        content: Text(
          'Ambil ${batch.orders.length} pesanan sekaligus?\n\n'
          'Total jarak: ${DistanceCalculator.formatDistance(batch.totalDistance)}\n'
          'Estimasi waktu: ${batch.estimatedTime} menit',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
            ),
            child: const Text('Ya, Ambil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) throw 'User tidak terautentikasi';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userName = userDoc.data()?['name'] as String? ?? 'Kurir';

      final firestoreBatch = FirebaseFirestore.instance.batch();

      // Update semua order di batch
      for (int i = 0; i < batch.orders.length; i++) {
        final order = batch.orders[i];

        try {
          // Akses order langsung dari root collection 'orders'
          final orderRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(order.orderId);
          
          // Cek apakah order ada
          final orderDoc = await orderRef.get();
          if (!orderDoc.exists) {
            print('?? Order ${order.orderId} tidak ditemukan');
            continue;
          }

          firestoreBatch.update(orderRef, {
            'courierId': uid,
            'courierName': userName,
            'batchId': batch.id,
            'deliverySequence': i + 1, // Urutan delivery
            'claimedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Notifikasi ke customer (ambil userId dari order document)
          final orderData = orderDoc.data();
          final customerId = orderData?['userId'] as String?;
          
          if (customerId != null) {
            final notifRef = FirebaseFirestore.instance
                .collection('users')
                .doc(customerId)
                .collection('notifications')
                .doc();

            firestoreBatch.set(notifRef, {
              'type': 'order_claimed',
              'orderId': order.orderId,
              'courierName': userName,
              'deliverySequence': i + 1,
              'totalInBatch': batch.orders.length,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print('? Error update order ${order.orderId}: $e');
          // Lanjutkan ke order berikutnya
        }
      }

      await firestoreBatch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? ${batch.orders.length} pesanan berhasil diambil!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload batches
        _loadBatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _previewRoute(OrderBatch batch) async {
    try {
      // Convert OrderLocation to CourierOrder for map page
      List<CourierOrder> courierOrders;
      
      // Jika dari activeOrders (sudah on_delivery), langsung pakai data yang ada
      if (widget.activeOrders != null && widget.activeOrders!.isNotEmpty) {
        // Filter orders yang ada di batch (match by orderId)
        final batchOrderIds = batch.orders.map((o) => o.orderId).toSet();
        courierOrders = widget.activeOrders!
            .where((o) => batchOrderIds.contains(o.orderId))
            .toList();
        
        print('? Using ${courierOrders.length} orders from activeOrders (no Firestore fetch)');
      } else {
        // Mode normal: fetch dari Firestore
        courierOrders = [];
        
        for (final orderLoc in batch.orders) {
          try {
            // Query order dari root collection 'orders' langsung dengan document ID
            final orderDoc = await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderLoc.orderId)
                .get();
            
            if (orderDoc.exists && orderDoc.data() != null) {
              courierOrders.add(CourierOrder.fromFirestore(
                orderDoc.id,
                orderDoc.data()!,
              ));
            } else {
              print('?? Order ${orderLoc.orderId} tidak ditemukan di Firestore');
            }
          } catch (e) {
            print('? Error fetch order ${orderLoc.orderId}: $e');
            // Lanjutkan ke order berikutnya
          }
        }
      }

      if (!mounted) return;
      
      if (courierOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data pesanan yang valid untuk ditampilkan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Navigate to map preview
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => BatchRouteMapPage(
            orders: courierOrders,
            batchId: batch.id,
          ),
        ),
      );

      // If user tapped "Mulai Pengiriman", trigger pickup
      // HANYA jika bukan activeOrders mode (pesanan belum di-claim)
      if (result == true && mounted && widget.activeOrders == null) {
        _pickupBatch(batch);
      }
    } catch (e) {
      print('? Error _previewRoute: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat preview rute: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    
    // Tentukan title berdasarkan mode
    final title = widget.activeOrders != null 
        ? 'Pengiriman Batch'
        : 'Batch Pickup - Route Optimization';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Mengoptimalkan rute...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBatches,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _batches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.activeOrders != null 
                                  ? Icons.location_off 
                                  : Icons.check_circle_outline, 
                              size: 64, 
                              color: Colors.grey.shade400
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.activeOrders != null
                                  ? 'Pesanan tidak memiliki koordinat pengiriman'
                                  : 'Tidak ada pesanan yang menunggu pickup',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.activeOrders != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Alamat pengiriman perlu diperbarui dengan koordinat yang valid',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBatches,
                      child: _BatchContentView(
                        batch: _batches.first,
                        onOpenMaps: () => _openBatchInMaps(_batches.first),
                        onPreviewRoute: () => _previewRoute(_batches.first),
                        onPickup: widget.activeOrders != null ? null : () => _pickupBatch(_batches.first),
                        isActiveMode: widget.activeOrders != null,
                      ),
                    ),
    );
  }
}

class _BatchContentView extends StatelessWidget {
  final OrderBatch batch;
  final VoidCallback onOpenMaps;
  final VoidCallback onPreviewRoute;
  final VoidCallback? onPickup;
  final bool isActiveMode;

  const _BatchContentView({
    required this.batch,
    required this.onOpenMaps,
    required this.onPreviewRoute,
    this.onPickup,
    this.isActiveMode = false,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [orange.withOpacity(0.1), orange.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.route, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.id == 'batch_delivery' 
                          ? 'Rute Pengiriman Optimal' 
                          : 'Batch ${batch.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${batch.orders.length} Pesanan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.straighten, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          DistanceCalculator.formatDistance(batch.totalDistance),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '~${batch.estimatedTime} min',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Urutan pengiriman
        const Text(
          'Urutan Pengiriman:',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),

        // Order list
        ...List.generate(batch.orders.length, (index) {
          final order = batch.orders[index];
          return _OrderSequenceItem(
            sequenceNumber: index + 1,
            order: order,
            isLast: index == batch.orders.length - 1,
          );
        }),

        const SizedBox(height: 24),

        // Action button - Navigasi (langsung ke Maps)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onOpenMaps,
            icon: const Icon(Icons.navigation, size: 22),
            label: const Text(
              'Navigasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),

        // Tombol Preview Rute selalu tampil (baik active mode maupun normal)
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onPreviewRoute,
            icon: const Icon(Icons.map, size: 20),
            label: Text(isActiveMode ? 'Lihat Rute' : 'Preview Rute'),
            style: OutlinedButton.styleFrom(
              foregroundColor: orange,
              side: BorderSide(color: orange, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Tombol Ambil Batch hanya untuk mode normal (sebelum di-claim)
        if (!isActiveMode) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onPickup,
              icon: const Icon(Icons.shopping_bag, size: 20),
              label: const Text('Ambil Batch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

class _BatchCard extends StatefulWidget {
  final OrderBatch batch;
  final VoidCallback onOpenMaps;
  final VoidCallback onPreviewRoute;
  final VoidCallback? onPickup; // Nullable - tidak ada untuk activeOrders mode
  final bool isActiveMode; // True jika dari activeOrders

  const _BatchCard({
    required this.batch,
    required this.onOpenMaps,
    required this.onPreviewRoute,
  });

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    final batch = widget.batch;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: orange.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.route, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              batch.id == 'batch_delivery' 
                                  ? 'Pengiriman Batch' 
                                  : batch.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${batch.orders.length} orders',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (batch.id == 'batch_delivery')
                          Text(
                            'Pesanan yang sedang dalam pengiriman',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (batch.id == 'batch_delivery') const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.straighten, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DistanceCalculator.formatDistance(batch.totalDistance),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '~${batch.estimatedTime} min',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Urutan Pengiriman Optimal:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  // Order list dengan sequence number
                  ...List.generate(batch.orders.length, (index) {
                    final order = batch.orders[index];
                    return _OrderSequenceItem(
                      sequenceNumber: index + 1,
                      order: order,
                      isLast: index == batch.orders.length - 1,
                    );
                  }),

                  const SizedBox(height: 16),

                  // Action buttons
                  Column(
                    children: [
                      // Preview route button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onPreviewRoute,
                          icon: const Icon(Icons.map),
                          label: Text(widget.isActiveMode 
                              ? 'Lihat Rute di Peta' 
                              : 'Preview Rute di Peta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isActiveMode 
                                ? orange 
                                : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      // Hanya tampilkan buttons lain jika bukan active mode
                      if (!widget.isActiveMode) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onOpenMaps,
                              icon: const Icon(Icons.map),
                              label: const Text('Buka di Maps'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: orange,
                                side: BorderSide(color: orange),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onPickup,
                              icon: const Icon(Icons.shopping_bag),
                              label: const Text('Ambil Batch'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ], // End if !isActiveMode
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderSequenceItem extends StatelessWidget {
  final int sequenceNumber;
  final OrderLocation order;
  final bool isLast;

  const _OrderSequenceItem({
    required this.sequenceNumber,
    required this.order,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sequence indicator
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A00).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$sequenceNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Order info
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.recipientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.orderId.substring(0, 8),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.address.length > 50
                            ? '${order.address.substring(0, 50)}...'
                            : order.address,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${order.total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
