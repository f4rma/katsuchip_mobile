import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void initDeepLinks(BuildContext context) {
    // Handle deep link when app is already open
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(context, uri);
      },
      onError: (err) {
        print('Error handling deep link: $err');
      },
    );

    // Handle initial deep link when app opens from closed state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(context, uri);
      }
    });
  }

  void _handleDeepLink(BuildContext context, Uri uri) {
    print('?? Deep link received: $uri');

    // Format: katsuchip://payment/confirm/{orderId}
    if (uri.scheme == 'katsuchip' && uri.host == 'payment') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'confirm') {
        final orderId = segments[1];
        _confirmPayment(context, orderId);
      }
    }
  }

  Future<void> _confirmPayment(BuildContext context, String orderId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF7A00)),
                  SizedBox(height: 16),
                  Text('Memproses pembayaran...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Get order from Firestore
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          _showErrorDialog(context, 'Order tidak ditemukan');
        }
        return;
      }

      final orderData = orderDoc.data()!;
      final currentStatus = orderData['status'] as String?;

      // Check if already paid
      if (currentStatus == 'menunggu' || currentStatus == 'paid') {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          _showInfoDialog(context, 'Order ini sudah dibayar sebelumnya');
        }
        return;
      }

      // Update order status to menunggu (ready to be processed by admin)
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'menunggu',
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });

      print('? Order $orderId berhasil diupdate menjadi menunggu (paid)');

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showSuccessDialog(context, orderId);
      }
    } catch (e) {
      print('? Error confirming payment: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showErrorDialog(context, 'Gagal memproses pembayaran: $e');
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
            const SizedBox(width: 12),
            const Text('Pembayaran Berhasil!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pembayaran untuk order ini telah dikonfirmasi.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Order ID: $orderId',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status pesanan telah berubah menjadi "Dibayar"',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to orders page
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Lihat Pesanan'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 32),
            SizedBox(width: 12),
            Text('Informasi'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
