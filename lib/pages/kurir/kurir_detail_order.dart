import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../service/auth_service.dart';
import '../../service/courier_service.dart';
import '../../service/geocoding_service.dart';
import '../../models/courier_models.dart';

class KurirDetailOrder extends StatefulWidget {
  final String idPesanan;

  const KurirDetailOrder({
    super.key,
    required this.idPesanan,
  });

  @override
  State<KurirDetailOrder> createState() => _KurirDetailOrderState();
}

class _KurirDetailOrderState extends State<KurirDetailOrder> {
  final CourierService _layananKurir = CourierService();
  bool _sedangMemuat = false;
  String _namaKurir = '';
  late final Stream<CourierOrder?> _orderStream; // Cache stream

  @override
  void initState() {
    super.initState();
    // Buat stream SEKALI saja di initState, bukan di build method
    final uid = AuthService().currentUser?.uid ?? '';
    _orderStream = _layananKurir.getOrderStream(widget.idPesanan, uid);
    _muatNamaKurir();
  }

  Future<void> _muatNamaKurir() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _namaKurir = doc.data()?['name'] as String? ?? 'Kurir';
        });
      }
    } catch (e) {
      print('Error memuat nama kurir: $e');
    }
  }

  Future<void> _mulaiPengiriman(CourierOrder pesanan) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai Pengiriman'),
        content: Text('Mulai pengiriman pesanan #${pesanan.code}?'),
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
            child: const Text('Mulai'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    setState(() => _sedangMemuat = true);

    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) throw 'User tidak terautentikasi';
      
      print('?? UI: Memulai pengiriman');
      print('  - Order ID: ${pesanan.orderId}');
      print('  - Customer ID: ${pesanan.userId}');
      print('  - Courier ID: $uid');
      print('  - Order Code: ${pesanan.code}');

      await _layananKurir.startDelivery(
        orderId: pesanan.orderId,
        courierId: uid,
        courierName: _namaKurir,
        customerId: pesanan.userId,
        orderCode: pesanan.code,
      );
      
      print('? UI: Pengiriman berhasil dimulai!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengiriman dimulai!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('? UI Error _mulaiPengiriman: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sedangMemuat = false);
      }
    }
  }

  Future<void> _tandaiTerkirim(CourierOrder pesanan) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Terkirim'),
        content: Text(
          'Konfirmasi bahwa pesanan #${pesanan.code} telah diterima customer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Terkirim'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    setState(() => _sedangMemuat = true);

    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) throw 'User tidak terautentikasi';
      
      print('?? UI: Menandai pesanan terkirim');
      print('  - Order ID: ${pesanan.orderId}');
      print('  - Customer ID: ${pesanan.userId}');
      print('  - Courier ID: $uid');
      print('  - Order Code: ${pesanan.code}');

      await _layananKurir.markAsDelivered(
        orderId: pesanan.orderId,
        courierId: uid,
        courierName: _namaKurir,
        customerId: pesanan.userId,
        orderCode: pesanan.code,
      );
      
      print('Pesanan berhasil dikirim!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dikirim!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('? UI Error _selesaiPengiriman: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sedangMemuat = false);
      }
    }
  }

  Future<void> _bukaGoogleMaps(CourierOrder pesanan) async {
    // Helper untuk validasi koordinat
    bool isValid(double? lat, double? lng) {
      if (lat == null || lng == null) return false;
      if (lat == 0 && lng == 0) return false;
      if (lat < -90 || lat > 90) return false;
      if (lng < -180 || lng > 180) return false;
      return true;
    }

    // Deteksi kemungkinan koordinat tertukar (lat > 90 dan lon dalam rentang lat)
    Map<String, double> maybeSwap(double lat, double lng) {
      if (lat.abs() > 90 && lng.abs() <= 90) {
        // Swap
        return {'lat': lng, 'lng': lat};
      }
      return {'lat': lat, 'lng': lng};
    }

    final lat = pesanan.latitude;
    final lng = pesanan.longitude;

    // Cek apakah koordinat valid (bukan 0,0 dan dalam rentang)
    if (!isValid(lat, lng)) {
      print('? Koordinat tidak valid: lat=$lat, lng=$lng');
      
      // Coba geocode ulang dari alamat
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Mencari lokasi...'),
              ],
            ),
          ),
        );
      }
      
      try {
        // Geocode ulang dari alamat
        final coordinates = await GeocodingService.getCoordinates(pesanan.address);
        
        if (mounted) Navigator.pop(context); // Close loading
        
        if (coordinates != null) {
          final newLat = coordinates['latitude']!;
          final newLng = coordinates['longitude']!;
          
          print('? Geocoding ulang berhasil: $newLat, $newLng');
          
          // Buka Google Maps dengan koordinat baru
          final url = Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=$newLat,$newLng&travelmode=driving');
          
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            throw 'Tidak dapat membuka Google Maps';
          }
          
          // Optional: Update koordinat di Firestore untuk next time
          try {
            final orderRef = FirebaseFirestore.instance
                .collection('orders')
                .doc(pesanan.orderId);
            
            await orderRef.update({
              'latitude': newLat,
              'longitude': newLng,
            });
            
            print('? Koordinat disimpan ke Firestore');
          } catch (e) {
            print('? Gagal update koordinat di Firestore: $e');
            // Tidak menghentikan proses, Maps tetap dibuka
          }
          
          return;
        } else {
          print('? Geocoding ulang gagal - alamat tidak ditemukan');
          
          if (mounted) {
            // Fallback: Buka Google Maps dengan alamat text
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Koordinat Tidak Tersedia'),
                content: const Text(
                  'Koordinat lokasi tidak ditemukan.\n\n'
                  'Buka Google Maps dengan pencarian alamat?',
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
                    child: const Text('Buka Maps'),
                  ),
                ],
              ),
            );
            
            if (confirmed == true) {
              // Encode alamat untuk URL
              final encodedAddress = Uri.encodeComponent(pesanan.address);
              final url = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
              
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
          }
          return;
        }
      } catch (e) {
        print('? Error saat geocoding: $e');
        
        if (mounted) {
          // Close loading dialog if still open
          Navigator.of(context, rootNavigator: true).pop();
        }
        
        if (mounted) {
          // Fallback langsung: buka dengan alamat text tanpa konfirmasi
          print('? Fallback: membuka Maps dengan pencarian alamat text');
          
          final encodedAddress = Uri.encodeComponent(pesanan.address);
          final url = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
          
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak dapat membuka Google Maps'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }
    }

    // Koordinat valid - kemungkinan perlu swap
    final adjusted = maybeSwap(lat!, lng!);
    final finalLat = adjusted['lat']!;
    final finalLng = adjusted['lng']!;
    final directionsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$finalLat,$finalLng&travelmode=driving');
    final searchUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$finalLat,$finalLng');

    try {
      if (await canLaunchUrl(directionsUrl)) {
        await launchUrl(directionsUrl, mode: LaunchMode.externalApplication);
      } else {
        print('? Directions gagal, mencoba search URL');
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

  Future<void> _teleponCustomer(String nomorTelepon) async {
    final url = Uri.parse('tel:$nomorTelepon');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Tidak dapat menelepon';
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

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    const bg = Color(0xFFFFF4DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Detail Pesanan'),
      ),
      body: StreamBuilder<CourierOrder?>(
        stream: _orderStream, // Gunakan cached stream, BUKAN panggil getOrderStream lagi
        builder: (context, snapshot) {
          print('?? StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, data: ${snapshot.data?.code}');
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final pesanan = snapshot.data;
          if (pesanan == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('Pesanan tidak ditemukan'),
                  const SizedBox(height: 8),
                  Text('ID: ${widget.idPesanan}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Order info card
                  _KartuInfo(
                    judul: 'Informasi Pesanan',
                    children: [
                      _BariInfo(label: 'Kode', nilai: '#${pesanan.code}'),
                      _BariInfo(
                        label: 'Status',
                        nilai: pesanan.deliveryStatusLabel,
                        warnaValue: _dapatkanWarnaStatus(pesanan.deliveryStatus),
                      ),
                      _BariInfo(label: 'Total', nilai: _rupiah(pesanan.total)),
                      _BariInfo(
                        label: 'Waktu Order',
                        nilai: _formatTanggalWaktu(pesanan.createdAt),
                      ),
                      if (pesanan.deliveryStartedAt != null)
                        _BariInfo(
                          label: 'Mulai Kirim',
                          nilai: _formatTanggalWaktu(pesanan.deliveryStartedAt!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Customer info card
                  _KartuInfo(
                    judul: 'Data Penerima',
                    children: [
                      _BariInfo(label: 'Nama', nilai: pesanan.recipientName),
                      _BariInfo(
                        label: 'Telepon',
                        nilai: pesanan.recipientPhone,
                        trailing: IconButton(
                          icon: const Icon(Icons.phone, color: orange),
                          onPressed: () => _teleponCustomer(pesanan.recipientPhone),
                        ),
                      ),
                      _BariInfo(
                        label: 'Alamat',
                        nilai: pesanan.address,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Items card
                  _KartuInfo(
                    judul: 'Item Pesanan (${pesanan.items.length})',
                    children: pesanan.items
                        .map((item) => _BariItem(
                              nama: item['name'] as String? ?? '-',
                              qty: (item['qty'] as num?)?.toInt() ?? 0,
                              harga: (item['price'] as num?)?.toInt() ?? 0,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // Google Maps button
                  if (pesanan.latitude != null && pesanan.longitude != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _bukaGoogleMaps(pesanan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.map),
                        label: const Text('Buka di Google Maps'),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),

              // Action buttons at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buatTombolAksi(pesanan),
                ),
              ),

              // Loading overlay
              if (_sedangMemuat)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buatTombolAksi(CourierOrder pesanan) {
    const orange = Color(0xFFFF7A00);

    switch (pesanan.deliveryStatus.toLowerCase()) {
      case 'waiting_pickup':
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _mulaiPengiriman(pesanan),
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Mulai Pengiriman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

      case 'on_delivery':
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _tandaiTerkirim(pesanan),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Tandai Terkirim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

      case 'delivered':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Pesanan Telah Terkirim',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Color _dapatkanWarnaStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting_pickup':
        return Colors.orange;
      case 'on_delivery':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _KartuInfo extends StatelessWidget {
  final String judul;
  final List<Widget> children;

  const _KartuInfo({
    required this.judul,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BariInfo extends StatelessWidget {
  final String label;
  final String nilai;
  final Color? warnaValue;
  final Widget? trailing;
  final int maxLines;

  const _BariInfo({
    required this.label,
    required this.nilai,
    this.warnaValue,
    this.trailing,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nilai,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: warnaValue,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _BariItem extends StatelessWidget {
  final String nama;
  final int qty;
  final int harga;

  const _BariItem({
    required this.nama,
    required this.qty,
    required this.harga,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = qty * harga;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_rupiah(harga)} • $qty',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _rupiah(subtotal),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF7A00),
            ),
          ),
        ],
      ),
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

String _formatTanggalWaktu(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.day}/${dt.month}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
