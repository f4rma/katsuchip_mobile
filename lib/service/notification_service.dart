import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/courier_models.dart';

/// Service untuk mengelola notifikasi antar role
class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Admin -> Kurir: Pesanan siap untuk diambil
  Future<void> notifyAdminToAllCouriers({
    required String orderId,
    required String orderCode,
    required String adminId,
  }) async {
    try {
      // Ambil semua kurir yang aktif
      final couriersSnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'courier')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _db.batch();

      for (var courierDoc in couriersSnapshot.docs) {
        final courierId = courierDoc.id;

        // Tambahkan notifikasi ke collection notifikasi kurir
        final notifRef = _db
            .collection('users')
            .doc(courierId)
            .collection('notifications')
            .doc();

        batch.set(notifRef, {
          'type': 'order_available',
          'orderId': orderId,
          'orderCode': orderCode,
          'message': 'Pesanan baru tersedia untuk dikirim: #$orderCode',
          'from': 'admin',
          'fromId': adminId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Log notifikasi ke collection logs
      final logRef = _db.collection('notification_logs').doc();
      batch.set(logRef, NotificationLog(
        id: logRef.id,
        type: 'admin_to_courier',
        from: 'admin:$adminId',
        to: 'couriers:all',
        orderId: orderId,
        message: 'Pesanan #$orderCode tersedia untuk pengiriman',
        data: {'orderCode': orderCode},
        createdAt: DateTime.now(),
      ).toMap());

      await batch.commit();

      print('? Notifikasi admin->kurir untuk order $orderCode berhasil dikirim');
    } catch (e) {
      print('? Error notifyAdminToAllCouriers: $e');
      rethrow;
    }
  }

  /// Kurir -> Pembeli: Kurir mulai pengiriman
  Future<void> notifyCourierToCustomer({
    required String orderId,
    required String orderCode,
    required String courierId,
    required String customerId,
    required String courierName,
    required String message,
  }) async {
    try {
      final batch = _db.batch();

      // Tambahkan notifikasi ke collection notifikasi customer
      final notifRef = _db
          .collection('users')
          .doc(customerId)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'type': 'delivery_update',
        'orderId': orderId,
        'orderCode': orderCode,
        'message': message,
        'from': 'courier',
        'fromId': courierId,
        'courierName': courierName,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log notifikasi
      final logRef = _db.collection('notification_logs').doc();
      batch.set(logRef, NotificationLog(
        id: logRef.id,
        type: 'courier_to_customer',
        from: 'courier:$courierId',
        to: 'customer:$customerId',
        orderId: orderId,
        message: message,
        data: {
          'orderCode': orderCode,
          'courierName': courierName,
        },
        createdAt: DateTime.now(),
      ).toMap());

      await batch.commit();

      print('? Notifikasi kurir->pembeli untuk order $orderCode berhasil');
    } catch (e) {
      print('? Error notifyCourierToCustomer: $e');
      rethrow;
    }
  }

  /// Kurir -> Admin: Update status pengiriman
  Future<void> notifyCourierToAdmin({
    required String orderId,
    required String orderCode,
    required String courierId,
    required String courierName,
    required String message,
    required String statusType, // 'started' atau 'completed'
  }) async {
    try {
      // Ambil semua admin
      final adminsSnapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final batch = _db.batch();

      for (var adminDoc in adminsSnapshot.docs) {
        final adminId = adminDoc.id;

        // Tambahkan notifikasi ke collection notifikasi admin
        final notifRef = _db
            .collection('users')
            .doc(adminId)
            .collection('notifications')
            .doc();

        batch.set(notifRef, {
          'type': 'delivery_status',
          'orderId': orderId,
          'orderCode': orderCode,
          'statusType': statusType,
          'message': message,
          'from': 'courier',
          'fromId': courierId,
          'courierName': courierName,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Log notifikasi
      final logRef = _db.collection('notification_logs').doc();
      batch.set(logRef, NotificationLog(
        id: logRef.id,
        type: 'courier_to_admin',
        from: 'courier:$courierId',
        to: 'admins:all',
        orderId: orderId,
        message: message,
        data: {
          'orderCode': orderCode,
          'courierName': courierName,
          'statusType': statusType,
        },
        createdAt: DateTime.now(),
      ).toMap());

      await batch.commit();

      print('? Notifikasi kurir->admin untuk order $orderCode berhasil');
    } catch (e) {
      print('? Error notifyCourierToAdmin: $e');
      rethrow;
    }
  }

  /// Ambil notifikasi untuk user tertentu
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  /// Tandai notifikasi sebagai sudah dibaca
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('? Error markAsRead: $e');
    }
  }

  /// Hapus notifikasi
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('? Error deleteNotification: $e');
    }
  }

  /// Ambil log notifikasi (untuk admin monitoring)
  Stream<List<NotificationLog>> getNotificationLogsStream({int limit = 100}) {
    return _db
        .collection('notification_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationLog.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Ambil jumlah notifikasi yang belum dibaca
  Stream<int> getUnreadCountStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
