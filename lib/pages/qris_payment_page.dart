import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_detail.dart';

class QRISPaymentPage extends StatefulWidget {
  final Map<String, dynamic> qrisData;
  final int totalAmount;
  final String orderId;
  final VoidCallback onPaymentConfirmed;

  const QRISPaymentPage({
    super.key,
    required this.qrisData,
    required this.totalAmount,
    required this.orderId,
    required this.onPaymentConfirmed,
  });

  @override
  State<QRISPaymentPage> createState() => _QRISPaymentPageState();
}

class _QRISPaymentPageState extends State<QRISPaymentPage> {
  Timer? _countdownTimer;
  Timer? _statusCheckTimer;
  Duration _remainingTime = const Duration(minutes: 15);
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startStatusCheck(); // Enable real-time status monitoring
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }
  
  void _startStatusCheck() {
    // Check payment status every 3 seconds
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isCheckingStatus) return; // Prevent overlapping checks
      
      _isCheckingStatus = true;
      
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          timer.cancel();
          return;
        }
        
        // Check order status from user subcollection only (better for permissions)
        final orderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('orders')
            .doc(widget.orderId)
            .get();
        
        if (orderDoc.exists) {
          final data = orderDoc.data() as Map<String, dynamic>;
          final paymentStatus = data['paymentStatus'] as String?;
          final orderStatus = data['status'] as String?;
          
          // If payment is successful, show success dialog
          if (paymentStatus == 'paid' && orderStatus == 'menunggu') {
            timer.cancel();
            _countdownTimer?.cancel();
            
            if (!mounted) return;
            
            // Show success dialog
            _showPaymentSuccessDialog(data);
          }
        }
      } catch (e) {
        debugPrint('Error checking payment status: $e');
      } finally {
        _isCheckingStatus = false;
      }
    });
  }

  void _startCountdown() {
    // Parse expiry time dari Midtrans
    final expiryTime = widget.qrisData['expiry_time'] as String?;
    if (expiryTime != null) {
      try {
        final expiry = DateTime.parse(expiryTime);
        _remainingTime = expiry.difference(DateTime.now());
      } catch (e) {
        print('Error parsing expiry time: $e');
      }
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        } else {
          timer.cancel();
          _showTimeoutDialog();
        }
      });
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Waktu Habis'),
        content: const Text(
          'Waktu pembayaran QRIS telah habis. Silakan buat pesanan baru.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccessDialog(Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pembayaran Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pesanan Anda sedang diproses',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Anda akan diarahkan ke halaman detail pesanan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                
                // Close dialog and QRIS page
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close QRIS page
                
                // Navigate to order detail
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailPage(
                      uid: uid,
                      orderId: widget.orderId,
                      orderData: orderData,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Lihat Pesanan Saya',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final qrCodeUrl = widget.qrisData['qr_code_url'] as String?;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        title: const Text('Pembayaran QRIS'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Countdown Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _remainingTime.inMinutes < 5
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _remainingTime.inMinutes < 5
                      ? Colors.red.shade300
                      : Colors.orange.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: _remainingTime.inMinutes < 5
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selesaikan dalam: ${_formatDuration(_remainingTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _remainingTime.inMinutes < 5
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Total Amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(widget.totalAmount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order ID: ${widget.orderId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // QR Code
            if (qrCodeUrl != null) ...[            
              
              const Text(
                'Scan QR Code di bawah ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'https://us-central1-katsuchip-65298.cloudfunctions.net/paymentSuccess?order_id=${widget.orderId}&amount=${widget.totalAmount}',
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (cxt, err) {
                    return Container(
                      width: 250,
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 8),
                          Text('Gagal membuat QR Code'),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // Instruksi Testing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, 
                             color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Cara Menggunakan QR Code:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep('1', 'Buka aplikasi pembayaran (GoPay, Dana, OVO, dll)'),
                    _buildInstructionStep('2', 'Pilih menu Scan QR atau Bayar'),
                    _buildInstructionStep('3', 'Scan QR Code di atas'),
                    _buildInstructionStep('4', 'Konfirmasi pembayaran di aplikasi'),
                    _buildInstructionStep('5', 'Kembali ke aplikasi KatsuChip untuk melihat status pesanan'),
                    const SizedBox(height: 8),                    
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('QR Code tidak tersedia'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons            
            if (qrCodeUrl != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadQRCode(qrCodeUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text(
                    'Download QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Pop 2x: tutup QRIS page dan checkout page
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                label: const Text(
                  'Kembali',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),            
          ],
        ),
      ),
    );
  }

  Future<void> _downloadQRCode(String qrCodeUrl) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
        ),
      );

      // Generate QR Code untuk webhook URL (bukan Midtrans URL)
      final webhookUrl = 'https://us-central1-katsuchip-65298.cloudfunctions.net/paymentSuccess?order_id=${widget.orderId}&amount=${widget.totalAmount}';
      
      // Create QR image using qr_flutter
      final qrValidationResult = QrValidator.validate(
        data: webhookUrl,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );
      
      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception('Invalid QR data');
      }
      
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );
      
      // Convert to image
      final picData = await painter.toImageData(500, format: ui.ImageByteFormat.png);
      if (picData == null) {
        throw Exception('Failed to generate QR image');
      }

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('Cannot access storage');
      }

      // Save file
      final fileName = 'KatsuChip_QR_${widget.orderId}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(picData.buffer.asUint8List());

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code berhasil diunduh'),
          backgroundColor: Color(0xFFFF7A00),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);
      
      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal download QR Code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
