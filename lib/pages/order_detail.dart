import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class OrderDetailPage extends StatefulWidget {
  final String uid;
  final String orderId;
  final Map<String, dynamic> orderData;
  const OrderDetailPage({
    super.key,
    required this.uid,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Timer? _countdownTimer;
  Duration? _remainingTime;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _checkAndStartCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _checkAndStartCountdown() {
    final status = widget.orderData['status'] as String? ?? 'pending';
    final qrisData = widget.orderData['qrisData'] as Map<String, dynamic>?;
    
    if (status == 'pending' && qrisData != null) {
      final expiryTime = qrisData['expiry_time'] as String?;
      if (expiryTime != null) {
        try {
          final expiry = DateTime.parse(expiryTime);
          final now = DateTime.now();
          
          if (now.isAfter(expiry)) {
            _isExpired = true;
            _autoCancelOrder();
          } else {
            _remainingTime = expiry.difference(now);
            _startCountdown();
          }
        } catch (e) {
          print('Error parsing expiry time: $e');
        }
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
            _remainingTime = Duration(seconds: _remainingTime!.inSeconds - 1);
          } else {
            timer.cancel();
            _isExpired = true;
            _autoCancelOrder();
          }
        });
      }
    });
  }

  Future<void> _autoCancelOrder() async {
    try {
      // Update status ke cancelled di Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': 'cancelled'});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan dibatalkan karena pembayaran tidak diselesaikan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error auto-canceling order: $e');
    }
  }

  Future<void> _downloadQRCode(String qrCodeUrl) async {
    try {
      // Request storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      // For Android 13+, use photos permission
      if (!status.isGranted) {
        status = await Permission.photos.status;
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission ditolak. Tidak dapat menyimpan QR code.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Mengunduh QR Code...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Download image
      final response = await http.get(Uri.parse(qrCodeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download QR code');
      }

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final fileName = 'qris_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Save to gallery using gal package
      await Gal.putImage(filePath, album: 'KatsuChip');

      // Delete temporary file
      await file.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('QR Code berhasil disimpan ke galeri'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error downloading QR Code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final dt = _asDate(widget.orderData['createdAt']);
    final items = (widget.orderData['items'] as List<dynamic>? ?? [])
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final addr = (widget.orderData['shippingAddress'] as Map<String, dynamic>? ?? {});
    final payment = _paymentLabel(widget.orderData['paymentMethod'] as String?);
    final status = _statusLabel((widget.orderData['status'] as String?) ?? 'pending');
    final code = (widget.orderData['code'] as String?) ??
        (widget.orderId.length >= 6 ? widget.orderId.substring(0, 6).toUpperCase() : widget.orderId.toUpperCase());

    final subtotal = items.fold<int>(
      0,
      (p, e) => p +
          ((e['price'] as num?)?.toInt() ?? 0) * ((e['qty'] as num?)?.toInt() ?? 0),
    );
    final total = (widget.orderData['total'] as num?)?.toInt() ?? subtotal;

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
                
                // Tampilkan ongkir jika ada
                () {
                  final shippingFee = (widget.orderData['shippingFee'] as num?)?.toInt();
                  final deliveryDistance = (widget.orderData['deliveryDistance'] as num?)?.toDouble();
                  
                  if (shippingFee != null && shippingFee > 0) {
                    String label = 'Ongkos Kirim';
                    if (deliveryDistance != null && deliveryDistance > 0) {
                      label += deliveryDistance < 1.0
                          ? ' (${(deliveryDistance * 1000).toStringAsFixed(0)} m)'
                          : ' (${deliveryDistance.toStringAsFixed(1)} km)';
                    }
                    return _RowSpaced(label, 'Rp ${_rupiah(shippingFee)}');
                  } else if (shippingFee == 0) {
                    return _RowSpaced('Ongkos Kirim', 'GRATIS', 
                      rightColor: Colors.green);
                  }
                  return const SizedBox.shrink();
                }(),
                
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
                        onPressed: () async {
                          // WhatsApp admin/penjual
                          const adminPhone = '6282284519884'; // Ganti dengan nomor admin
                          final orderId = widget.orderData['orderId'] ?? 'unknown';
                          final message = Uri.encodeComponent(
                            'Halo Admin KatsuChip, saya ingin bertanya tentang pesanan saya dengan ID: $orderId'
                          );
                          final whatsappUri = Uri.parse('https://wa.me/$adminPhone?text=$message');
                          
                          if (await canLaunchUrl(whatsappUri)) {
                            await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tidak bisa membuka WhatsApp')),
                              );
                            }
                          }
                        },
                        child: const Text('Hubungi Penjual'),
                      ),
                    ),
                  ],
                ),

                // Tampilkan QR Code jika status pending dan ada QRIS data
                if ((widget.orderData['status'] as String?) == 'pending' && 
                    widget.orderData['qrisData'] != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildQRISSection(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRISSection(BuildContext context) {
    final qrisData = widget.orderData['qrisData'] as Map<String, dynamic>;
    final qrCodeUrl = qrisData['qr_code_url'] as String?;

    if (_isExpired) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          children: [
            Icon(Icons.access_time_filled, size: 48, color: Colors.red.shade700),
            const SizedBox(height: 12),
            Text(
              'Pembayaran Expired',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Waktu pembayaran telah habis. Pesanan dibatalkan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          // Countdown Timer
          if (_remainingTime != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _remainingTime!.inMinutes < 5
                    ? Colors.red.shade100
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _remainingTime!.inMinutes < 5
                      ? Colors.red.shade400
                      : Colors.orange.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: _remainingTime!.inMinutes < 5
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selesaikan dalam: ${_formatDuration(_remainingTime!)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _remainingTime!.inMinutes < 5
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Scan QR Code untuk Pembayaran',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),          

          // QR Code Image
          if (qrCodeUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.network(
                qrCodeUrl,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    width: 200,
                    height: 200,
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
                    width: 200,
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 40, color: Colors.red),
                        SizedBox(height: 8),
                        Text('Gagal memuat QR Code', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),          
            // How to Test Payment
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Cara Simulasi Pembayaran:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Buka aplikasi pembayaran (GoPay, Dana, OVO, dll)\n'
                    '2. Pilih menu Scan QR atau Bayar\n'
                    '3. Scan QR Code di atas\n'
                    '4. Konfirmasi pembayaran di aplikasi\n'
                    '5. Kembali ke aplikasi KatsuChip untuk melihat status pesanan\n',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Download Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadQRCode(qrCodeUrl),
                icon: const Icon(Icons.download, size: 20),
                label: const Text('Simpan QR Code ke Galeri'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('QR Code tidak tersedia', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
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
  final Color? rightColor;
  const _RowSpaced(
    this.left,
    this.right, {
    this.bold = false,
    this.multilineRight = false,
    this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    final rightWidget = Text(
      right.isEmpty ? '-' : right,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: rightColor,
      ),
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
                  Text('x$qty • Rp ${_rupiah(price)}'),
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
      return 'Menunggu Pembayaran';
    case 'paid':
      return 'Pembayaran Berhasil';
    case 'menunggu':
      return 'Menunggu Konfirmasi';
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