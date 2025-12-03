import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum untuk status pengiriman
enum DeliveryStatus {
  waitingPickup('waiting_pickup', 'Menunggu Diambil'),
  onDelivery('on_delivery', 'Sedang Dikirim'),
  delivered('delivered', 'Terkirim');

  final String value;
  final String label;
  const DeliveryStatus(this.value, this.label);

  static DeliveryStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'waiting_pickup':
        return DeliveryStatus.waitingPickup;
      case 'on_delivery':
        return DeliveryStatus.onDelivery;
      case 'delivered':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.waitingPickup;
    }
  }
}

/// Model untuk statistik kurir
class CourierStats {
  final int onDeliveryCount;
  final int deliveredTodayCount;
  final int totalDeliveries;

  const CourierStats({
    required this.onDeliveryCount,
    required this.deliveredTodayCount,
    required this.totalDeliveries,
  });

  factory CourierStats.empty() => const CourierStats(
        onDeliveryCount: 0,
        deliveredTodayCount: 0,
        totalDeliveries: 0,
      );
}

/// Model untuk order dengan informasi pengiriman
class CourierOrder {
  final String orderId;
  final String code;
  final String userId;
  final String recipientName;
  final String recipientPhone;
  final String address;
  final double? latitude;
  final double? longitude;
  final num total;
  final String status;
  final String deliveryStatus;
  final DateTime createdAt;
  final DateTime? deliveryStartedAt;
  final DateTime? deliveredAt;
  final String? courierId;
  final List<Map<String, dynamic>> items;

  CourierOrder({
    required this.orderId,
    required this.code,
    required this.userId,
    required this.recipientName,
    required this.recipientPhone,
    required this.address,
    this.latitude,
    this.longitude,
    required this.total,
    required this.status,
    required this.deliveryStatus,
    required this.createdAt,
    this.deliveryStartedAt,
    this.deliveredAt,
    this.courierId,
    required this.items,
  });

  factory CourierOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final shippingAddress = data['shippingAddress'] as Map<String, dynamic>? ?? {};
    final createdAtRaw = data['createdAt'];
    final deliveryStartedAtRaw = data['deliveryStartedAt'];
    final deliveredAtRaw = data['deliveredAt'];

    // Handle multiple format shippingAddress:
    // Format 1 (terbaru): {name, phone, address} - lengkap dengan data penerima
    // Format 2 (lama): {id, detail, title} - hanya alamat tanpa data penerima
    String recipientName = shippingAddress['name'] as String? ?? 'Penerima';
    String recipientPhone = shippingAddress['phone'] as String? ?? '-';
    String address = shippingAddress['address'] as String? ?? 
                     shippingAddress['detail'] as String? ?? 
                     data['address'] as String? ?? '-';
    
    return CourierOrder(
      orderId: id,
      code: data['code'] as String? ?? id.substring(0, 6).toUpperCase(),
      userId: data['userId'] as String? ?? '',
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      address: address,
      latitude: (shippingAddress['latitude'] as num?)?.toDouble() ?? 
                (data['latitude'] as num?)?.toDouble(),
      longitude: (shippingAddress['longitude'] as num?)?.toDouble() ?? 
                 (data['longitude'] as num?)?.toDouble(),
      total: data['total'] as num? ?? 0,
      status: data['status'] as String? ?? 'pending',
      deliveryStatus: data['deliveryStatus'] as String? ?? 'waiting_pickup',
      createdAt: _parseTimestamp(createdAtRaw),
      deliveryStartedAt: deliveryStartedAtRaw != null ? _parseTimestamp(deliveryStartedAtRaw) : null,
      deliveredAt: deliveredAtRaw != null ? _parseTimestamp(deliveredAtRaw) : null,
      courierId: data['courierId'] as String?,
      items: (data['items'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.now();
  }

  String get deliveryStatusLabel => DeliveryStatus.fromString(deliveryStatus).label;
}

/// Model untuk notifikasi
class NotificationLog {
  final String id;
  final String type;
  final String from;
  final String to;
  final String orderId;
  final String message;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  NotificationLog({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.orderId,
    required this.message,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'from': from,
        'to': to,
        'orderId': orderId,
        'message': message,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory NotificationLog.fromFirestore(String id, Map<String, dynamic> data) {
    return NotificationLog(
      id: id,
      type: data['type'] as String? ?? '',
      from: data['from'] as String? ?? '',
      to: data['to'] as String? ?? '',
      orderId: data['orderId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      data: data['data'] as Map<String, dynamic>? ?? {},
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.now();
  }
}
