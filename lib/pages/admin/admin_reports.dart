import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_appbar_actions.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        backgroundColor: orange,
        foregroundColor: Colors.white,
        actions: adminAppBarActions(context),
      ),
      body: FutureBuilder<_Report>(
        future: _Report.loadLast30Days(),
        builder: (context, snap) {
          if (snap.hasError) {
            final err = snap.error;
            String msg = 'Gagal memuat laporan';
            if (err is FirebaseException) {
              msg = err.message ?? msg;
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
                    const SizedBox(height: 10),
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Pastikan aturan Firestore mengizinkan admin membaca collectionGroup("orders").',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _metric('Total Pendapatan', r.revenue, color: Colors.green),
              const SizedBox(height: 10),
              _metric('Total Pesanan', r.count.toDouble(), color: Colors.blue),
              const SizedBox(height: 10),
              _metric('Menu Terjual (item)', r.totalItemsSold.toDouble(), color: orange),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Text('Belum ada grafik terperinci. (To-do: tambahkan chart)'),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String label, double v, {Color color = Colors.orange}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
  CircleAvatar(backgroundColor: color.withValues(alpha: .15), child: Icon(Icons.bar_chart_rounded, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(label.contains('Pendapatan') ? _rupiah(v) : v.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ])),
      ]),
    );
  }
}

class _Report {
  final int count;
  final double revenue;
  final int totalItemsSold;
  _Report({required this.count, required this.revenue, required this.totalItemsSold});

  static Future<_Report> loadLast30Days() async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 30));
    final db = FirebaseFirestore.instance;
    QuerySnapshot<Map<String, dynamic>> qs;
    try {
      // Jalur utama: butuh single-field index COLLECTION_GROUP_ASC(createdAt)
      qs = await db
          .collectionGroup('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
    } on FirebaseException catch (e) {
      // Fallback sementara bila index ASC belum siap: ambil DESC (butuh index DESC)
      // lalu filter di memori. Batasi jumlah untuk menjaga performa.
      if (e.code == 'failed-precondition') {
        qs = await db
            .collectionGroup('orders')
            .orderBy('createdAt', descending: true)
            .limit(1000)
            .get();
      } else {
        rethrow;
      }
    }

    int count = 0;
    double revenue = 0;
    int items = 0;
    final sinceMs = since.millisecondsSinceEpoch;
    for (final d in qs.docs) {
      final ts = d.data()['createdAt'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (ts is int) dt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is num) dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      if (dt == null || dt.millisecondsSinceEpoch < sinceMs) {
        // Jika fallback DESC, dokumen lebih lama dari 30 hari akan di-skip
        continue;
      }
      count += 1;
      revenue += ((d['total'] ?? 0) as num).toDouble();
      final its = (d['items'] as List?) ?? const [];
      for (final it in its) {
        final qty = ((it as Map)['qty'] ?? 0) as num;
        items += qty.toInt();
      }
    }
    return _Report(count: count, revenue: revenue, totalItemsSold: items);
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
