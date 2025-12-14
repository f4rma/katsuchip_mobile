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
                final status = _statusLabel((data['status'] as String?) ?? 'pending');

                // Check if QRIS payment is pending and not expired
                final isPendingQris = (data['status'] as String?) == 'pending' && 
                                      data['qrisData'] != null &&
                                      (data['paymentMethod'] as String?) == 'qris';
                final qrisData = data['qrisData'] as Map<String, dynamic>?;
                bool isQrisExpired = false;
                
                if (isPendingQris && qrisData != null) {
                  final expiryTime = qrisData['expiry_time'] as String?;
                  if (expiryTime != null) {
                    try {
                      final expiry = DateTime.parse(expiryTime);
                      isQrisExpired = DateTime.now().isAfter(expiry);
                    } catch (e) {
                      isQrisExpired = false;
                    }
                  }
                }
                
                // Item luar yang simple (seperti sebelumnya)
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(
                        uid: uid,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StatusChip(text: status, statusCode: data['status'] as String? ?? 'pending'),
                            if (isPendingQris && !isQrisExpired) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.qr_code, size: 14, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Lihat QR',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        // Show QR Code preview for pending QRIS orders
                        if (isPendingQris && !isQrisExpired && qrisData != null) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.qr_code_scanner, color: Colors.orange.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Scan QR Code untuk Pembayaran',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (qrisData['qr_code_url'] != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.network(
                                      qrisData['qr_code_url'],
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return SizedBox(
                                          width: 150,
                                          height: 150,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              color: const Color(0xFFFF7A00),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 150,
                                          height: 150,
                                          color: Colors.grey.shade200,
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.error_outline, size: 30, color: Colors.red),
                                              SizedBox(height: 4),
                                              Text('Gagal memuat QR', style: TextStyle(fontSize: 10)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap untuk melihat detail & download',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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

class _StatusChip extends StatelessWidget {
  final String text;
  final String statusCode;
  const _StatusChip({required this.text, required this.statusCode});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    
    switch (statusCode.toLowerCase()) {
      case 'pending':
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        textColor = const Color(0xFFFF7A00);
        break;
      case 'processing':
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        textColor = Colors.blue.shade700;
        break;
      case 'delivering':
        bgColor = Colors.purple.shade50;
        borderColor = Colors.purple.shade300;
        textColor = Colors.purple.shade700;
        break;
      case 'delivered':
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade700;
        break;
      case 'cancelled':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade700;
        break;
      default:
        bgColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'pending':
      return 'Menunggu Pembayaran';
    case 'paid':
      return 'Pembayaran Berhasil';
    case 'menunggu':
      return 'Menunggu';
    case 'processing':
    case 'diproses':
      return 'Sedang Diproses';
    case 'delivering':
    case 'diantar':
      return 'Sedang Diantar';
    case 'delivered':
    case 'completed': // Backward compatibility
    case 'diterima':
      return 'Pesanan Diterima';
    case 'cancelled':
      return 'Dibatalkan';
    default:
      return 'Menunggu';
  }
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
