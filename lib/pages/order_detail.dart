import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderDetailPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  const OrderDetailPage({super.key, required this.orderId, required this.orderData});

  @override
  Widget build(BuildContext context) {
    final dt = _asDate(orderData['createdAt']);
    final items = (orderData['items'] as List<dynamic>? ?? [])
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final addr = (orderData['shippingAddress'] as Map<String, dynamic>? ?? {});
    final payment = _paymentLabel(orderData['paymentMethod'] as String?);
    final status = _statusLabel((orderData['status'] as String?) ?? 'pending');
    final code = (orderData['code'] as String?) ??
        (orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase());

    final subtotal = items.fold<int>(
      0,
      (p, e) => p +
          ((e['price'] as num?)?.toInt() ?? 0) * ((e['qty'] as num?)?.toInt() ?? 0),
    );
    final total = (orderData['total'] as num?)?.toInt() ?? subtotal;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        title: const Text('Riwayat Pesanan'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header order + status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order #$code',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_fmtLongIndo(dt),
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    _StatusChip(text: status),
                  ],
                ),
                const SizedBox(height: 12),

                // Ringkas item pertama (ikut desain)
                if (items.isNotEmpty) ...[
                  Text(items.first['name'] as String? ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${(items.first['qty'] as num?)?.toInt() ?? 0}x Rp ${_rupiah((items.first['price'] as num?)?.toInt() ?? 0)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                if (items.length > 1)
                  Text('+ ${items.length - 1} item lainnya',
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),

                const SizedBox(height: 8),
                const Divider(),

                // Rincian harga, pembayaran, alamat
                const SizedBox(height: 6),
                _RowSpaced('Subtotal', 'Rp ${_rupiah(subtotal)}', bold: true),
                _RowSpaced('Pembayaran', payment),
                _RowSpaced(
                  'Alamat',
                  _joinAddr(addr),
                  multilineRight: true,
                ),

                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),

                Row(
                  children: [
                    const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
                    Text('Rp ${_rupiah(total)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),

                const SizedBox(height: 12),

                // Tombol aksi
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showAllItems(context, items, subtotal, total),
                        child: const Text('Detail'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Fitur hubungi penjual segera tersedia')),
                          );
                        },
                        child: const Text('Hubungi Penjual'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RowSpaced extends StatelessWidget {
  final String left;
  final String right;
  final bool bold;
  final bool multilineRight;
  const _RowSpaced(this.left, this.right, {this.bold = false, this.multilineRight = false});

  @override
  Widget build(BuildContext context) {
    final rightWidget = Text(
      right.isEmpty ? '-' : right,
      textAlign: TextAlign.right,
      style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: multilineRight ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(width: 90, child: Text(left, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 8),
          Expanded(child: rightWidget),
        ],
      ),
    );
  }
}

void _showAllItems(BuildContext context, List<Map<String, dynamic>> items, int subtotal, int total) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detail Item', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...items.map((e) {
            final name = e['name'] as String? ?? '-';
            final price = (e['price'] as num?)?.toInt() ?? 0;
            final qty = (e['qty'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(name)),
                  Text('x$qty  •  Rp ${_rupiah(price)}'),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            children: [
              const Expanded(child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('Rp ${_rupiah(subtotal)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('Rp ${_rupiah(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

String _joinAddr(Map<String, dynamic> addr) {
  final title = (addr['title'] as String?) ?? '';
  final detail = (addr['detail'] as String?) ?? '';
  return [if (title.isNotEmpty) title, if (detail.isNotEmpty) detail].join('\n');
}

DateTime _asDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.now();
}

String _fmtLongIndo(DateTime dt) {
  const bulan = [
    'Januari','Februari','Maret','April','Mei','Juni',
    'Juli','Agustus','September','Oktober','November','Desember'
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  final jam = '${two(dt.hour)}.${two(dt.minute)}';
  return '${dt.day} ${bulan[dt.month - 1]} ${dt.year} pukul $jam';
}

String _rupiah(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    b.write(s[i]);
    if (idx > 1 && idx % 3 == 1) b.write('.');
  }
  return b.toString();
}

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

String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'pending':
      return 'Diproses';
    case 'paid':
      return 'Dibayar';
    case 'completed':
      return 'Selesai';
    case 'canceled':
      return 'Dibatalkan';
    default:
      return 'Diproses';
  }
}