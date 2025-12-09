import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../service/notification_service.dart';
import '../../service/auth_service.dart';

class AdminOrderDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const AdminOrderDetailPage({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final data = doc.data();
    final code = data['code'] as String? ?? doc.id;
    final uid = data['userId'] as String? ?? '-';
    final total = (data['total'] ?? 0) as num;
    final status = data['status'] as String? ?? 'pending';
    final paymentStatus = data['paymentStatus'] as String? ?? 'unpaid';
    final paymentMethod = data['paymentMethod'] as String? ?? '-';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final when = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '-';

    final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final shippingAddress = (data['shippingAddress'] as Map<String, dynamic>?) ?? const {};
    final recipientName = shippingAddress['name'] as String? ?? '-';
    final address = shippingAddress['address'] as String? ?? '-';
    final phoneNumber = shippingAddress['phone'] as String? ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: Text('Pesanan #$code'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: 'Informasi Pesanan', children: [
            _InfoRow(label: 'Kode Pesanan', value: code),
            _InfoRow(label: 'User ID', value: uid),
            _InfoRow(label: 'Tanggal', value: when),
            _InfoRow(label: 'Status', value: status),
            _InfoRow(label: 'Status Pembayaran', value: paymentStatus),
            _InfoRow(label: 'Metode Pembayaran', value: paymentMethod),
            _InfoRow(label: 'Total Belanja', value: _rupiah(total), bold: true),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Data Penerima', children: [
            _InfoRow(label: 'Nama', value: recipientName),
            _InfoRow(label: 'Nomor HP', value: phoneNumber),
            _InfoRow(label: 'Alamat', value: address, maxLines: 3),
          ]),
          const SizedBox(height: 16),
          _Section(
            title: 'Item Pesanan (${items.length})',
            children: [
              for (final item in items)
                _ItemCard(
                  name: item['name'] as String? ?? '-',
                  price: (item['price'] ?? 0) as num,
                  qty: (item['qty'] ?? 0) as num,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ActionButtons(doc: doc, status: status),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;
  final bool bold;
  const _InfoRow({required this.label, required this.value, this.maxLines = 1, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String name;
  final num price;
  final num qty;
  const _ItemCard({required this.name, required this.price, required this.qty});

  @override
  Widget build(BuildContext context) {
    final subtotal = price * qty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_rupiah(price)} • $qty', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
        Text(_rupiah(subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String status;
  const _ActionButtons({required this.doc, required this.status});

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);

    Widget btn(String text, VoidCallback onTap, {Color? color}) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: (color ?? orange),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(text),
        ),
      );
    }

    List<Widget> actions() {
      switch (status) {
        case 'pending':
          // Setelah pembayaran, admin mulai proses pesanan
          return [
            btn('Proses Pesanan', () => _update(doc, 'processing', context)),
            const SizedBox(height: 8),
            btn('Batalkan Pesanan', () => _update(doc, 'cancelled', context), color: Colors.grey),
          ];
        case 'processing':
          // Setelah selesai dimasak, serahkan ke kurir untuk diantar
          return [btn('Antarkan (Serahkan ke Kurir)', () => _update(doc, 'delivering', context))];
        case 'delivering':
          // Status delivering dihandle oleh kurir, admin hanya monitor
          return [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pesanan sedang diantar oleh kurir',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          ];
        case 'delivered':
          // Pesanan sudah selesai diantar oleh kurir
          return [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pesanan telah diterima pembeli',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          ];
        case 'cancelled':
          return [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Pesanan dibatalkan',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            )
          ];
        default:
          return [const SizedBox.shrink()];
      }
    }

    return Column(children: actions());
  }

  Future<void> _update(QueryDocumentSnapshot<Map<String, dynamic>> doc, String next, BuildContext context) async {
    await doc.reference.update({'status': next, 'updatedAt': FieldValue.serverTimestamp()});
    
    final uid = (doc.data()['userId'] as String?) ?? '';
    final code = (doc.data()['code'] as String?) ?? doc.id;
    
    // Notifikasi ke user
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').add({
        'type': 'order_status',
        'orderId': doc.id,
        'status': next,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    // Jika status 'delivering', kirim notifikasi ke semua kurir
    if (next == 'delivering') {
      final adminId = AuthService().currentUser?.uid ?? '';
      try {
        await NotificationService().notifyAdminToAllCouriers(
          orderId: doc.id,
          orderCode: code,
          adminId: adminId,
        );
      } catch (e) {
        print('Error notifying couriers: $e');
      }
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status diubah ke $next')));
      Navigator.pop(context);
    }
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
