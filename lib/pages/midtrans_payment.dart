import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../service/midtrans_service.dart';
import '../models/models.dart';

/// Halaman untuk menangani pembayaran dengan Midtrans
/// Akan generate snap token, launch Midtrans UI, dan handle callback
class MidtransPaymentPage extends StatefulWidget {
  final String orderId;
  final String orderCode;
  final double total;
  final List<CartItem> items;
  final Map<String, dynamic> shippingAddress;

  const MidtransPaymentPage({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.total,
    required this.items,
    required this.shippingAddress,
  });

  @override
  State<MidtransPaymentPage> createState() => _MidtransPaymentPageState();
}

class _MidtransPaymentPageState extends State<MidtransPaymentPage> {
  final MidtransService _midtrans = MidtransService();
  bool _isProcessing = false;
  String _status = 'Memproses pembayaran...';

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _status = 'Menghubungi server pembayaran...';
    });

    try {
      // Get user data
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'User tidak terautentikasi';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userName = userDoc.data()?['name'] as String? ?? 'Customer';
      final userEmail = userDoc.data()?['email'] as String? ?? 'customer@katsuchip.com';
      final userPhone = userDoc.data()?['phone'] as String? ?? '08123456789';

      setState(() => _status = 'Membuat transaksi pembayaran...');

      // Format items untuk Midtrans
      final midtransItems = widget.items.map((item) {
        return {
          'id': item.item.id,
          'name': item.item.name,
          'price': item.item.price,
          'qty': item.qty,
        };
      }).toList();

      // Generate snap token
      final snapToken = await _midtrans.getSnapToken(
        orderId: widget.orderCode, // Gunakan order code sebagai order ID
        grossAmount: widget.total.toInt(),
        customerName: userName,
        customerEmail: userEmail,
        customerPhone: userPhone,
        items: midtransItems,
      );

      if (snapToken == null) {
        throw 'Gagal membuat transaksi pembayaran';
      }

      setState(() => _status = 'Membuka halaman pembayaran...');

      // Launch Midtrans payment UI
      final result = await _midtrans.startPayment(
        snapToken: snapToken,
        orderId: widget.orderCode,
      );

      if (result != null) {
        // Update payment status di Firestore
        await _midtrans.updatePaymentStatus(
          userId: uid,
          orderId: widget.orderId,
          transactionStatus: result,
        );

        final transactionStatus = result['transaction_status'] as String?;
        
        if (mounted) {
          if (transactionStatus == 'settlement' || transactionStatus == 'capture') {
            // Payment success
            _showResultDialog(
              success: true,
              message: 'Pembayaran berhasil! Pesanan Anda sedang diproses.',
            );
          } else if (transactionStatus == 'pending') {
            // Payment pending
            _showResultDialog(
              success: true,
              message: 'Menunggu pembayaran. Silakan selesaikan pembayaran Anda.',
            );
          } else {
            // Payment failed/cancelled
            _showResultDialog(
              success: false,
              message: 'Pembayaran dibatalkan atau gagal.',
            );
          }
        }
      } else {
        throw 'Tidak dapat memverifikasi status pembayaran';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'Error: $e';
        });
        
        _showResultDialog(
          success: false,
          message: 'Terjadi kesalahan: $e',
        );
      }
    }
  }

  void _showResultDialog({required bool success, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(success ? 'Berhasil' : 'Gagal'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Close payment page
              if (success) {
                Navigator.of(context).pop(); // Close checkout page
                Navigator.of(context).pop(); // Close cart page, back to main
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4DE),
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button during processing
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(
                  color: Color(0xFFFF7A00),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Order #${widget.orderCode}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
