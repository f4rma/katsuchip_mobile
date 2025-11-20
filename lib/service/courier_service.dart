import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/courier_models.dart';
import 'notification_service.dart';

/// Service untuk operasi kurir
class CourierService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Stream pesanan yang tersedia untuk kurir (status = 'delivering')
  Stream<List<CourierOrder>> getAvailableOrdersStream() {
    return _db
        .collection('orders')
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
  Stream<List<CourierOrder>> getOrdersByDeliveryStatusStream(
      String deliveryStatus) {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'delivering')
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
        .collection('orders')
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
          .collection('orders')
          .where('courierId', isEqualTo: courierId)
          .where('deliveryStatus', isEqualTo: 'on_delivery')
          .get();

      // Count pesanan terkirim hari ini
      final deliveredTodaySnapshot = await _db
          .collection('orders')
          .where('courierId', isEqualTo: courierId)
          .where('deliveryStatus', isEqualTo: 'delivered')
          .where('deliveredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Total pengiriman
      final totalSnapshot = await _db
          .collection('orders')
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
      final batch = _db.batch();

      // Update order
      final orderRef = _db.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'deliveryStatus': 'on_delivery',
        'courierId': courierId,
        'deliveryStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

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
      final batch = _db.batch();

      // Update order
      final orderRef = _db.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': 'completed',
        'deliveryStatus': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

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
    } catch (e) {
      print('✗ Error markAsDelivered: $e');
      rethrow;
    }
  }

  /// Ambil detail pesanan
  Future<CourierOrder?> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return CourierOrder.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      print('✗ Error getOrderById: $e');
      return null;
    }
  }

  /// Stream detail pesanan
  Stream<CourierOrder?> getOrderStream(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return CourierOrder.fromFirestore(doc.id, doc.data()!);
    });
  }

  /// Claim pesanan (kurir mengambil pesanan)
  Future<void> claimOrder({
    required String orderId,
    required String courierId,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'courierId': courierId,
        'deliveryStatus': 'waiting_pickup',
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ Pesanan $orderId di-claim oleh kurir $courierId');
    } catch (e) {
      print('✗ Error claimOrder: $e');
      rethrow;
    }
  }
}
