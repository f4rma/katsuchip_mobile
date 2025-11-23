import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../service/auth_service.dart';
import '../../service/courier_service.dart';
import '../../models/courier_models.dart';
import 'kurir_detail_order.dart';

class KurirDashboard extends StatefulWidget {
  const KurirDashboard({super.key});

  @override
  State<KurirDashboard> createState() => _KurirDashboardState();
}

class _KurirDashboardState extends State<KurirDashboard> {
  final CourierService _layananKurir = CourierService();
  String _filterStatus = 'semua'; // semua, waiting_pickup, on_delivery
  String _namaKurir = '';

  @override
  void initState() {
    super.initState();
    _muatNamaKurir();
    _checkActiveStatus();
  }

  /// Real-time check status aktif kurir
  void _checkActiveStatus() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      
      final isActive = doc.data()?['isActive'] as bool?;
      
      // Jika dinonaktifkan, auto logout
      if (isActive == false) {
        _showDeactivatedDialog();
      }
    });
  }

  void _showDeactivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Akun Dinonaktifkan'),
        content: const Text(
          'Akun Anda telah dinonaktifkan oleh admin.\n\n'
          'Silakan hubungi admin untuk informasi lebih lanjut.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  Future<void> _keluar() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    const bg = Color(0xFFFFF7ED);
    final uid = AuthService().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Dashboard Kurir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _keluar,
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF9933)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat datang kembali!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _namaKurir,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statistics
            FutureBuilder<CourierStats>(
              future: _layananKurir.getCourierStats(uid),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? CourierStats.empty();
                
                return Row(
                  children: [
                    Expanded(
                      child: _KartuStatistik(
                        icon: Icons.local_shipping_outlined,
                        label: 'Sedang Dikirim',
                        nilai: '${stats.onDeliveryCount}',
                        warna: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KartuStatistik(
                        icon: Icons.check_circle_outline,
                        label: 'Terkirim Hari Ini',
                        nilai: '${stats.deliveredTodayCount}',
                        warna: Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Filter chips
            Row(
              children: [
                const Text(
                  'Filter:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ChipFilter(
                          label: 'Semua',
                          terpilih: _filterStatus == 'semua',
                          onTap: () => setState(() => _filterStatus = 'semua'),
                        ),
                        const SizedBox(width: 8),
                        _ChipFilter(
                          label: 'Menunggu Pickup',
                          terpilih: _filterStatus == 'waiting_pickup',
                          onTap: () => setState(() => _filterStatus = 'waiting_pickup'),
                        ),
                        const SizedBox(width: 8),
                        _ChipFilter(
                          label: 'Dalam Pengiriman',
                          terpilih: _filterStatus == 'on_delivery',
                          onTap: () => setState(() => _filterStatus = 'on_delivery'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Orders list
            StreamBuilder<List<CourierOrder>>(
              stream: _filterStatus == 'semua'
                  ? _layananKurir.getAvailableOrdersStream()
                  : _layananKurir.getOrdersByDeliveryStatusStream(_filterStatus),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final daftarPesanan = snapshot.data ?? [];

                if (daftarPesanan.isEmpty) {
                  return _KosongState(filterStatus: _filterStatus);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesanan (${daftarPesanan.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...daftarPesanan.map((pesanan) => _KartuPesanan(
                          pesanan: pesanan,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => KurirDetailOrder(
                                  idPesanan: pesanan.orderId,
                                ),
                              ),
                            );
                          },
                        )),
                  ],
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _KartuStatistik extends StatelessWidget {
  final IconData icon;
  final String label;
  final String nilai;
  final Color warna;

  const _KartuStatistik({
    required this.icon,
    required this.label,
    required this.nilai,
    required this.warna,
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
        children: [
          Icon(icon, color: warna, size: 32),
          const SizedBox(height: 8),
          Text(
            nilai,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: warna,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFilter extends StatelessWidget {
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  const _ChipFilter({
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: terpilih ? orange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: terpilih ? orange : Colors.grey.shade300,
          ),
          boxShadow: terpilih
              ? [
                  BoxShadow(
                    color: orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: terpilih ? Colors.white : Colors.black87,
            fontWeight: terpilih ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _KartuPesanan extends StatelessWidget {
  final CourierOrder pesanan;
  final VoidCallback onTap;

  const _KartuPesanan({
    required this.pesanan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final warnaStatus = _dapatkanWarnaStatus(pesanan.deliveryStatus);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pesanan #${pesanan.code}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pesanan.recipientName,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: warnaStatus.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: warnaStatus),
                  ),
                  child: Text(
                    pesanan.deliveryStatusLabel,
                    style: TextStyle(
                      color: warnaStatus,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pesanan.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                  pesanan.recipientPhone,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  _rupiah(pesanan.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _KosongState extends StatelessWidget {
  final String filterStatus;

  const _KosongState({required this.filterStatus});

  @override
  Widget build(BuildContext context) {
    String pesan;
    IconData icon;

    switch (filterStatus) {
      case 'waiting_pickup':
        pesan = 'Tidak ada pesanan yang menunggu pickup';
        icon = Icons.shopping_bag_outlined;
        break;
      case 'on_delivery':
        pesan = 'Tidak ada pesanan dalam pengiriman';
        icon = Icons.local_shipping_outlined;
        break;
      default:
        pesan = 'Belum ada pesanan tersedia';
        icon = Icons.inbox_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
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
