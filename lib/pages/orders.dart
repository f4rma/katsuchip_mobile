import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../service/cart_repository.dart';
import 'order_detail.dart';

class OrdersPage extends StatelessWidget {
  final String uid;
  const OrdersPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final repo = CartRepository();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repo.ordersStream(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = [...(snapshot.data?.docs ?? const [])];

            // urutkan terbaru di atas
            docs.sort((a, b) {
              final da = _asDate(a.data()['createdAt']);
              final db = _asDate(b.data()['createdAt']);
              return db.compareTo(da);
            });

            final count = docs.length;

            if (docs.isEmpty) {
              // Header + empty state
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(count: count),
                  const SizedBox(height: 16),
                  _emptyState(context),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: count + 1, // + header
              itemBuilder: (context, i) {
                if (i == 0) return _Header(count: count);
                final d = docs[i - 1];
                final data = d.data();

                final dt = _asDate(data['createdAt']);
                final total = (data['total'] as num?)?.toInt() ?? 0;
                final payment = _paymentLabel(data['paymentMethod'] as String?);

                // Item luar yang simple (seperti sebelumnya)
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(
                        orderId: d.id,
                        orderData: data,
                      ),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: Color(0xFFFF7A00)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_fmt(dt), style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(payment, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Text('Rp ${_formatRupiah(total)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: const [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black26),
          SizedBox(height: 10),
          Text('Belum Ada Pesanan', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Yuk, pesan makanan favorit kamu sekarang!',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A00),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_back, color: Colors.white), // hiasan saja
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Riwayat Pesanan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count Pesanan',
              style: const TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Removed unused _StatusChip widget

String _paymentLabel(String? code) {
  switch ((code ?? '').toLowerCase()) {
    case 'bri':
      return 'Transfer Bank BRI';
    case 'mandiri':
      return 'Transfer Bank Mandiri';
    case 'nagari':
      return 'Transfer Bank Nagari';
    case 'qris':
      return 'QRIS';
    default:
      return '-';
  }
}

// Removed unused helper widgets and labels that are not referenced in this page.

DateTime _asDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.now();
}

String _fmt(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

String _formatRupiah(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write('.');
  }
  return buf.toString();
}
