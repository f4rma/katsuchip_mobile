import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/courier_models.dart';
import 'notification_service.dart';

/// Service untuk operasi kurir
class CourierService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Stream pesanan yang tersedia untuk kurir (status = 'delivering' dan belum diambil kurir lain)
  Stream<List<CourierOrder>> getAvailableOrdersStream() {
    return _db
        .collectionGroup('orders')
        .where('status', isEqualTo: 'delivering')
        .where('deliveryStatus', isEqualTo: 'waiting_pickup')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CourierOrder.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Stream SEMUA pesanan dengan status 'delivering' untuk kurir (untuk filter "Semua")
  /// Kurir bisa lihat semua order (seperti sebelumnya)
  Stream<List<CourierOrder>> getAllOrdersStream(String courierId) {
    return _db
        .collectionGroup('orders')
        .where('status', isEqualTo: 'delivering')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CourierOrder.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Stream pesanan berdasarkan delivery status
  /// Kurir bisa lihat semua order (seperti sebelumnya)
  Stream<List<CourierOrder>> getOrdersByDeliveryStatusStream(
      String deliveryStatus, String courierId) {
    return _db
        .collectionGroup('orders')
        .where('deliveryStatus', isEqualTo: deliveryStatus)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CourierOrder.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Stream pesanan yang sedang dikerjakan kurir tertentu
  Stream<List<CourierOrder>> getCourierActiveOrdersStream(String courierId) {
    return _db
        .collectionGroup('orders')
        .where('courierId', isEqualTo: courierId)
        .where('deliveryStatus', whereIn: ['waiting_pickup', 'on_delivery'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CourierOrder.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Ambil statistik kurir
  Future<CourierStats> getCourierStats(String courierId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Count pesanan sedang dikirim
      final onDeliverySnapshot = await _db
          .collectionGroup('orders')
          .where('courierId', isEqualTo: courierId)
          .where('deliveryStatus', isEqualTo: 'on_delivery')
          .get();

      // Count pesanan terkirim hari ini
      final deliveredTodaySnapshot = await _db
          .collectionGroup('orders')
          .where('courierId', isEqualTo: courierId)
          .where('deliveryStatus', isEqualTo: 'delivered')
          .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Total pengiriman
      final totalSnapshot = await _db
          .collectionGroup('orders')
          .where('courierId', isEqualTo: courierId)
          .where('deliveryStatus', isEqualTo: 'delivered')
          .get();

      return CourierStats(
        onDeliveryCount: onDeliverySnapshot.docs.length,
        deliveredTodayCount: deliveredTodaySnapshot.docs.length,
        totalDeliveries: totalSnapshot.docs.length,
      );
    } catch (e) {
      print('✗ Error getCourierStats: $e');
      return CourierStats.empty();
    }
  }

  /// Kurir mulai pengiriman
  Future<void> startDelivery({
    required String orderId,
    required String courierId,
    required String courierName,
    required String customerId,
    required String orderCode,
  }) async {
    try {
      print('🚀 Memulai pengiriman: orderId=$orderId, customerId=$customerId');
      print('   Kurir ID: $courierId');
      
      // Cek role user kurir
      final kurirDoc = await _db.collection('users').doc(courierId).get();
      if (!kurirDoc.exists) {
        throw 'User kurir tidak ditemukan';
      }
      
      final kurirRole = kurirDoc.data()?['role'];
      print('   Role kurir: $kurirRole');
      
      if (kurirRole != 'kurir') {
        throw 'User tidak memiliki role kurir. Role saat ini: $kurirRole';
      }
      
      // Langsung gunakan path lengkap: users/{userId}/orders/{orderId}
      final orderRef = _db
          .collection('users')
          .doc(customerId)
          .collection('orders')
          .doc(orderId);
      
      // Cek apakah order exists
      final orderDoc = await orderRef.get();
      if (!orderDoc.exists) {
        print('✗ Order tidak ditemukan di path: users/$customerId/orders/$orderId');
        throw 'Order not found';
      }
      
      print('✓ Order ditemukan, melakukan update...');

      // Update order
      await orderRef.update({
        'deliveryStatus': 'on_delivery',
        'courierId': courierId,
        'deliveryStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✓ Update berhasil!');

      // Kirim notifikasi ke customer
      await _notificationService.notifyCourierToCustomer(
        orderId: orderId,
        orderCode: orderCode,
        courierId: courierId,
        customerId: customerId,
        courierName: courierName,
        message: 'Pesanan Anda sedang dalam perjalanan! Kurir: $courierName',
      );

      // Kirim notifikasi ke admin
      await _notificationService.notifyCourierToAdmin(
        orderId: orderId,
        orderCode: orderCode,
        courierId: courierId,
        courierName: courierName,
        message: 'Kurir $courierName memulai pengiriman pesanan #$orderCode',
        statusType: 'started',
      );

      print('✓ Pengiriman dimulai untuk order $orderCode');
    } catch (e) {
      print('✗ Error startDelivery: $e');
      rethrow;
    }
  }

  /// Kurir tandai pesanan sebagai terkirim
  Future<void> markAsDelivered({
    required String orderId,
    required String courierId,
    required String courierName,
    required String customerId,
    required String orderCode,
  }) async {
    try {
      print('📦 Menandai pesanan terkirim: orderId=$orderId, customerId=$customerId');
      print('   Path akan diakses: users/$customerId/orders/$orderId');
      print('   Kurir ID: $courierId');
      
      // Cek role user kurir
      final kurirDoc = await _db.collection('users').doc(courierId).get();
      if (!kurirDoc.exists) {
        throw 'User kurir tidak ditemukan';
      }
      
      final kurirRole = kurirDoc.data()?['role'];
      print('   Role kurir: $kurirRole');
      
      if (kurirRole != 'kurir') {
        throw 'User tidak memiliki role kurir. Role saat ini: $kurirRole';
      }
      
      // Langsung gunakan path lengkap: users/{userId}/orders/{orderId}
      final orderRef = _db
          .collection('users')
          .doc(customerId)
          .collection('orders')
          .doc(orderId);
      
      // Cek apakah order exists
      print('🔍 Mengecek order existence...');
      final orderDoc = await orderRef.get();
      if (!orderDoc.exists) {
        print('✗ Order tidak ditemukan di path: users/$customerId/orders/$orderId');
        throw 'Order not found';
      }
      
      print('✓ Order ditemukan!');
      print('   Current status: ${orderDoc.data()?['status']}');
      print('   Current deliveryStatus: ${orderDoc.data()?['deliveryStatus']}');
      print('🔄 Mencoba update order...');

      // Update order
      await orderRef.update({
        'status': 'completed',
        'deliveryStatus': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(), // Untuk auto-cleanup di Cloud Function
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✓ Pesanan berhasil ditandai terkirim!');

      // Kirim notifikasi ke customer
      await _notificationService.notifyCourierToCustomer(
        orderId: orderId,
        orderCode: orderCode,
        courierId: courierId,
        customerId: customerId,
        courierName: courierName,
        message: 'Pesanan Anda telah sampai! Terima kasih telah berbelanja.',
      );

      // Kirim notifikasi ke admin
      await _notificationService.notifyCourierToAdmin(
        orderId: orderId,
        orderCode: orderCode,
        courierId: courierId,
        courierName: courierName,
        message: 'Pesanan #$orderCode telah diterima customer',
        statusType: 'completed',
      );

      print('✓ Pesanan $orderCode ditandai sebagai terkirim');
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw 'Akses ditolak. Pastikan Anda login sebagai kurir dan Firestore rules sudah di-deploy.';
      } else if (e.code == 'not-found') {
        throw 'Pesanan tidak ditemukan. Path: users/$customerId/orders/$orderId';
      }
      
      throw 'Gagal menandai pesanan: ${e.message}';
    } catch (e) {
      print('✗ Error markAsDelivered: $e');
      rethrow;
    }
  }

  /// Ambil detail pesanan
  Future<CourierOrder?> getOrderById(String orderId) async {
    try {
      print('🔍 Mencari order dengan ID: $orderId');
      
      // Strategi 1: Cari berdasarkan field 'id'
      final docs = await _db
          .collectionGroup('orders')
          .where('id', isEqualTo: orderId)
          .limit(1)
          .get();
      
      if (docs.docs.isNotEmpty) {
        print('✓ Order ditemukan via field id');
        final doc = docs.docs.first;
        return CourierOrder.fromFirestore(doc.id, doc.data());
      }
      
      print('⚠ Order tidak ditemukan dengan field id, coba cari semua...');
      
      // Strategi 2: Cari di semua orders (fallback untuk debugging)
      final allOrders = await _db
          .collectionGroup('orders')
          .get();
      
      print('📦 Total orders ditemukan: ${allOrders.docs.length}');
      
      for (final doc in allOrders.docs) {
        print('  - Doc ID: ${doc.id}, Field id: ${doc.data()['id']}');
        if (doc.id == orderId || doc.data()['id'] == orderId) {
          print('✓ Order ditemukan via document ID match');
          return CourierOrder.fromFirestore(doc.id, doc.data());
        }
      }
      
      print('✗ Order tidak ditemukan sama sekali');
      return null;
    } catch (e) {
      print('✗ Error getOrderById: $e');
      return null;
    }
  }

  /// Stream detail pesanan untuk kurir tertentu
  /// Kurir bisa lihat semua order (seperti sebelumnya)
  Stream<CourierOrder?> getOrderStream(String orderId, String courierId) {
    print('🔍 Stream mencari order dengan ID: $orderId untuk kurir: $courierId');
    
    return _db
        .collectionGroup('orders')
        .where('id', isEqualTo: orderId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      print('📡 Stream update diterima: ${snapshot.docs.length} docs found');
      
      if (snapshot.docs.isEmpty) {
        print('⚠ Stream: Order dengan id=$orderId tidak ditemukan');
        return null;
      }
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      print('✓ Stream: Order ditemukan - Doc ID: ${doc.id}');
      print('  - Code: ${data['code']}');
      print('  - Status: ${data['status']}');
      print('  - DeliveryStatus: ${data['deliveryStatus']}');
      print('  - CourierId: ${data['courierId'] ?? "null"}');
      
      return CourierOrder.fromFirestore(doc.id, data);
    });
  }

  /// Claim pesanan (kurir mengambil pesanan)
  Future<void> claimOrder({
    required String orderId,
    required String userId,
    required String courierId,
  }) async {
    try {
      print('🎯 Mengambil pesanan: orderId=$orderId, userId=$userId, courierId=$courierId');
      
      // Langsung gunakan path lengkap: users/{userId}/orders/{orderId}
      final orderRef = _db
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId);
      
      // Cek apakah order exists
      final orderDoc = await orderRef.get();
      if (!orderDoc.exists) {
        print('✗ Order tidak ditemukan di path: users/$userId/orders/$orderId');
        throw 'Order not found';
      }
      
      print('✓ Order ditemukan, melakukan claim...');

      await orderRef.update({
        'courierId': courierId,
        'deliveryStatus': 'waiting_pickup',
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ Pesanan $orderId berhasil di-claim oleh kurir $courierId');
    } catch (e) {
      print('✗ Error claimOrder: $e');
      rethrow;
    }
  }
}
