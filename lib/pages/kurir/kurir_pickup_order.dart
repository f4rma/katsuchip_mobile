import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../service/route_optimization_service.dart';

/// Halaman untuk kurir mengambil pesanan
/// Mendukung pengambilan multiple orders yang searah
class KurirPickupOrderPage extends StatefulWidget {
  final String orderId;

  const KurirPickupOrderPage({super.key, required this.orderId});

  @override
  State<KurirPickupOrderPage> createState() => _KurirPickupOrderPageState();
}

class _KurirPickupOrderPageState extends State<KurirPickupOrderPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _nearbyOrders = [];
  final Set<String> _selectedOrders = {};

  @override
  void initState() {
    super.initState();
    _selectedOrders.add(widget.orderId); // Order utama selalu dipilih
    _loadNearbyOrders();
  }

  Future<void> _loadNearbyOrders() async {
    try {
      // Ambil data order utama
      final mainOrderDoc = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('id', isEqualTo: widget.orderId)
          .limit(1)
          .get();

      if (mainOrderDoc.docs.isEmpty) return;

      final mainOrder = mainOrderDoc.docs.first.data();
      final mainLat = (mainOrder['latitude'] ?? 0.0) as double;
      final mainLon = (mainOrder['longitude'] ?? 0.0) as double;

      // Cari pesanan lain yang ready_for_pickup dalam radius 2km
      final availableOrders = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('deliveryStatus', isEqualTo: 'waiting_pickup')
          .where('status', isEqualTo: 'delivering')
          .get();

      final List<Map<String, dynamic>> nearby = [];

      for (final doc in availableOrders.docs) {
        if (doc.id == widget.orderId) continue; // Skip order utama

        final data = doc.data();
        final lat = (data['latitude'] ?? 0.0) as double;
        final lon = (data['longitude'] ?? 0.0) as double;

        // Cek jarak
        if (RouteOptimizationService.isNearby(mainLat, mainLon, lat, lon, maxDistanceKm: 2.0)) {
          nearby.add({
            ...data,
            'docId': doc.id,
            'docRef': doc.reference,
            'distance': RouteOptimizationService.calculateDistance(mainLat, mainLon, lat, lon),
          });
        }
      }

      // Sort by distance
      nearby.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {
        _nearbyOrders = nearby;
      });
    } catch (e) {
      print('Error loading nearby orders: $e');
    }
  }

  Future<void> _pickupOrders() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final kurirId = AuthService().currentUser?.uid;
      if (kurirId == null) throw 'User not logged in';

      // Ambil nama kurir
      final kurirDoc = await FirebaseFirestore.instance.collection('users').doc(kurirId).get();
      final kurirName = kurirDoc.data()?['name'] as String? ?? 'Kurir';

      final batch = FirebaseFirestore.instance.batch();

      // Update semua pesanan yang dipilih
      for (final orderId in _selectedOrders) {
        // Cari document reference
        final orderDocs = await FirebaseFirestore.instance
            .collectionGroup('orders')
            .where('id', isEqualTo: orderId)
            .limit(1)
            .get();

        if (orderDocs.docs.isNotEmpty) {
          final orderRef = orderDocs.docs.first.reference;
          
          batch.update(orderRef, {
            'deliveryStatus': 'picked_up',
            'kurirId': kurirId,
            'kurirName': kurirName,
            'pickedUpAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Notify customer
          final userId = orderDocs.docs.first.data()['userId'] as String?;
          if (userId != null) {
            final notifRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .doc();

            batch.set(notifRef, {
              'type': 'order_picked_up',
              'orderId': orderId,
              'kurirName': kurirName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedOrders.length} pesanan berhasil diambil!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil pesanan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Ambil Pesanan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nearbyOrders.isEmpty
                              ? 'Tidak ada pesanan lain yang searah.'
                              : 'Ada ${_nearbyOrders.length} pesanan lain yang searah. Pilih untuk mengambil sekaligus!',
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main order
                const Text('Pesanan Utama:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                _OrderCard(
                  orderId: widget.orderId,
                  isSelected: true,
                  isMain: true,
                  onToggle: null, // Cannot unselect main order
                ),
                
                if (_nearbyOrders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Pesanan Searah:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._nearbyOrders.map((order) {
                    final orderId = order['docId'] as String;
                    final distance = order['distance'] as double;
                    
                    return Column(
                      children: [
                        _OrderCard(
                          orderId: orderId,
                          distance: distance,
                          isSelected: _selectedOrders.contains(orderId),
                          onToggle: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedOrders.add(orderId);
                              } else {
                                _selectedOrders.remove(orderId);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],

                const SizedBox(height: 24),

                // Pickup button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _pickupOrders,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _selectedOrders.length == 1
                          ? 'Ambil Pesanan'
                          : 'Ambil ${_selectedOrders.length} Pesanan',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final double? distance;
  final bool isSelected;
  final bool isMain;
  final Function(bool)? onToggle;

  const _OrderCard({
    required this.orderId,
    this.distance,
    required this.isSelected,
    this.isMain = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('id', isEqualTo: orderId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.docs.first.data();
        final code = data['code'] as String? ?? orderId;
        final address = data['address'] as String? ?? '';
        final total = (data['total'] ?? 0) as num;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF7A00) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (!isMain)
                Checkbox(
                  value: isSelected,
                  onChanged: onToggle != null ? (val) => onToggle!(val ?? false) : null,
                  activeColor: const Color(0xFFFF7A00),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('#$code', style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (isMain) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'UTAMA',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFF7A00)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_rupiah(total), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFFF7A00))),
                        if (distance != null) ...[
                          const Spacer(),
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Text('${distance!.toStringAsFixed(1)} km', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _rupiah(num n) {
  final s = n.toInt().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    b.write(s[i]);
    if (idx > 1 && idx % 3 == 1) b.write('.');
  }
  return 'Rp $b';
}
