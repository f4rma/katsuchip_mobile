import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_appbar_actions.dart';
import 'admin_menu.dart';
import 'admin_orders.dart';
import 'admin_kurir.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        actions: adminAppBarActions(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _HeaderCards(),
            SizedBox(height: 16),
            _QuickActions(),
            SizedBox(height: 16),
            _PendingOrdersCard(),
          ],
        ),
      ),
    );
  }
}

class _HeaderCards extends StatelessWidget {
  const _HeaderCards();

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            children: const [
              Expanded(child: _SmallStatBox(title: 'Pesanan Hari Ini', field: 'countToday')),
              SizedBox(width: 12),
              Expanded(child: _SmallStatBox(title: 'Total Pendapatan', field: 'revenue30')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStatBox extends StatelessWidget {
  final String title;
  final String field; // 'countToday' | 'revenue30'
  const _SmallStatBox({required this.title, required this.field});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: FutureBuilder<_DashboardStats>(
        future: _DashboardStats.load(),
        builder: (context, snap) {
          final stats = snap.data;
          String value = '-';
          if (stats != null) {
            value = field == 'countToday' ? '${stats.countToday}' : _formatCurrency(stats.revenue30Days);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color color = Colors.orange}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ])),
            const Icon(Icons.chevron_right_rounded)
          ]),
        ),
      );
    }

    return Column(children: [
      tile(Icons.inventory_2_outlined, 'Kelola Pesanan', 'Lihat dan update status pesanan', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminOrdersPage()));
      }),
      tile(Icons.restaurant_menu_rounded, 'Kelola Menu', 'Atur ketersediaan dan stok menu', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminMenuPage()));
      }, color: const Color(0xFFFF7A00)),
      tile(Icons.delivery_dining, 'Kelola Kurir', 'Tambah kurir baru dan kelola akun', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminKurirPage()));
      }, color: Colors.blue),
    ]);
  }
}

class _PendingOrdersCard extends StatelessWidget {
  const _PendingOrdersCard();

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pesanan Menunggu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        FutureBuilder<int>(
          future: _countPending(),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return Row(children: [
              Text('$count', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Perlu diproses segera', style: TextStyle(color: Colors.white70))),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminOrdersPage()));
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                child: const Text('Lihat'),
              )
            ]);
          },
        ),
      ]),
    );
  }
}

class _DashboardStats {
  final int countToday;
  final int revenue30Days;
  _DashboardStats({required this.countToday, required this.revenue30Days});

  static Future<_DashboardStats> load() async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final db = FirebaseFirestore.instance;
      
      // Query langsung ke collection 'orders'
      final ordersToday = await db.collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startToday))
          .get();

      // Query untuk pendapatan 30 hari terakhir (hanya yang sudah dibayar)
      final orders30 = await db.collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final countToday = ordersToday.size;
      
      // Hitung total pendapatan dari 30 hari (hanya pesanan yang sudah dibayar/selesai)
      int totalRevenue = 0;
      for (final doc in orders30.docs) {
        final data = doc.data();
        final paymentStatus = data['paymentStatus'] as String?;
        
        // Hanya hitung pesanan yang sudah dibayar (paymentStatus = 'paid')
        if (paymentStatus == 'paid') {
          final total = (data['total'] ?? 0) as num;
          totalRevenue += total.round();
        }
      }
      
      return _DashboardStats(countToday: countToday, revenue30Days: totalRevenue);
    } catch (e) {
      debugPrint('Dashboard stats error: $e');
      return _DashboardStats(countToday: 0, revenue30Days: 0);
    }
  }
}

String _formatCurrency(num v) {
  final s = v.toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write('.');
  }
  return 'Rp $buf';
}

Future<int> _countPending() async {
  try {
    final db = FirebaseFirestore.instance;
    
    // Hitung pesanan dengan status 'menunggu' dan 'paid'
    final snapshot = await db.collection('orders')
        .where('status', whereIn: ['menunggu', 'paid']).get();
    
    return snapshot.size;
  } catch (e) {
    debugPrint('Pending count error: $e');
    return 0;
  }
}
