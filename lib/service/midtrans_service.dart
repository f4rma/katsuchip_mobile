import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/api_keys.dart';

class MidtransService {
  // API keys diambil dari file terpisah yang di-gitignore
  static String get _clientKey => ApiKeys.midtransClientKey;
  static String get _serverKey => ApiKeys.midtransServerKey;
  static bool get _isProduction => ApiKeys.midtransIsProduction;

  /// Generate Snap Token dari server Midtrans
  /// PERHATIAN: Untuk production, generate token di backend/Cloud Function
  /// agar Server Key tidak exposed di client side
  Future<String?> getSnapToken({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final url = Uri.parse(
        _isProduction
            ? 'https://app.midtrans.com/snap/v1/transactions'
            : 'https://app.sandbox.midtrans.com/snap/v1/transactions',
      );

      // Encode Server Key ke Base64 untuk Authorization header
      final auth = base64Encode(utf8.encode('$_serverKey:'));

      final body = {
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount,
        },
        'customer_details': {
          'first_name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
        'item_details': items,
        'enabled_payments': [
          'qris', // QRIS
          'gopay',
          'shopeepay',
          'bca_va', // Virtual Account BCA
          'bni_va',
          'bri_va',
          'permata_va',
          'other_va', // Bank lainnya (termasuk Bank Nagari)
        ],
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['token'] as String?;
      } else {
        print('Error getting snap token: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception getting snap token: $e');
      return null;
    }
  }

  /// Check transaction status from Midtrans API
  Future<Map<String, dynamic>?> checkTransactionStatus(String orderId) async {
    try {
      final url = Uri.parse(
        _isProduction
            ? 'https://api.midtrans.com/v2/$orderId/status'
            : 'https://api.sandbox.midtrans.com/v2/$orderId/status',
      );

      final auth = base64Encode(utf8.encode('$_serverKey:'));

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Error checking status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception checking status: $e');
      return null;
    }
  }

  /// Update payment status di Firestore berdasarkan hasil dari Midtrans
  Future<void> updatePaymentStatus({
    required String userId,
    required String orderId,
    required Map<String, dynamic> transactionStatus,
  }) async {
    try {
      final transactionStatusStr = transactionStatus['transaction_status'] as String?;
      final fraudStatus = transactionStatus['fraud_status'] as String?;
      
      String paymentStatus = 'unpaid';
      
      if (transactionStatusStr == 'capture') {
        // For credit card
        if (fraudStatus == 'accept') {
          paymentStatus = 'paid';
        }
      } else if (transactionStatusStr == 'settlement') {
        paymentStatus = 'paid';
      } else if (transactionStatusStr == 'pending') {
        paymentStatus = 'pending';
      } else if (transactionStatusStr == 'deny' || 
                 transactionStatusStr == 'expire' ||
                 transactionStatusStr == 'cancel') {
        paymentStatus = 'failed';
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .update({
        'paymentStatus': paymentStatus,
        'midtransTransactionStatus': transactionStatusStr,
        'midtransFraudStatus': fraudStatus,
        'paymentUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('Payment status updated: $paymentStatus');
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }

  /// Helper: Format items untuk Midtrans API
  static List<Map<String, dynamic>> formatItems(List<Map<String, dynamic>> cartItems) {
    return cartItems.map((item) {
      return {
        'id': item['id'] as String,
        'name': item['name'] as String,
        'price': item['price'] as int,
        'quantity': item['qty'] as int,
      };
    }).toList();
  }

  /// Generate QRIS QR Code URL untuk pembayaran QRIS
  /// Return Map dengan qr_code_url dan expiry_time
  Future<Map<String, dynamic>?> generateQRIS({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final url = Uri.parse(
        _isProduction
            ? 'https://api.midtrans.com/v2/charge'
            : 'https://api.sandbox.midtrans.com/v2/charge',
      );

      // Encode Server Key ke Base64 untuk Authorization header
      final auth = base64Encode(utf8.encode('$_serverKey:'));

      final body = {
        'payment_type': 'qris',
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount,
        },
        'customer_details': {
          'first_name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
        'item_details': items,
        'qris': {
          'acquirer': 'gopay', // Specify acquirer for better QR code generation
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Basic $auth',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Extract QRIS data with safer null handling
        String? qrCodeUrl;
        String? qrString;
        
        // Try to get QR string directly from response
        if (data.containsKey('qr_string')) {
          qrString = data['qr_string'] as String?;
        }
        
        // If no qr_string, try to get from actions
        final actions = data['actions'];
        if (actions != null && actions is List) {
          try {
            final qrAction = actions.firstWhere(
              (action) => action != null && action['name'] == 'generate-qr-code',
              orElse: () => null,
            );
            if (qrAction != null) {
              qrCodeUrl = qrAction['url'] as String?;
              
              // If URL exists, fetch the actual QR string
              if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
                try {
                  final qrResponse = await http.get(Uri.parse(qrCodeUrl));
                  if (qrResponse.statusCode == 200) {
                    // The response body should be the QR code image
                    // Store the URL for display
                    qrCodeUrl = qrAction['url'] as String?;
                  }
                } catch (e) {
                  print('Error fetching QR code: $e');
                }
              }
            }
          } catch (e) {
            print('Error extracting QR code URL: $e');
          }
        }

        return {
          'status': data['transaction_status'],
          'order_id': data['order_id'],
          'gross_amount': data['gross_amount'],
          'qr_code_url': qrCodeUrl,
          'qr_string': qrString, // QRIS string for direct QR generation
          'transaction_id': data['transaction_id'],
          'merchant_id': data['merchant_id'],
          'acquirer': data['acquirer'],
          'expiry_time': data['expiry_time'],
        };
      } else {
        print('Error generating QRIS: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception generating QRIS: $e');
      return null;
    }
  }
}
