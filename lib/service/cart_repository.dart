import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import '../models/models.dart';
import 'geocoding_service.dart';

class CartRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cartCol(String uid) =>
      _db.collection('users').doc(uid).collection('cart');
  CollectionReference<Map<String, dynamic>> _orderCol(String uid) =>
      _db.collection('users').doc(uid).collection('orders');

  Future<List<CartItem>> fetchCart(String uid) async {
    final snap = await _cartCol(uid).get();
    return snap.docs.map((d) {
      final data = d.data();
      final item = MenuItemData.fromMap(data['item'] as Map<String, dynamic>);
      final qty = (data['qty'] as num).toInt();
      return CartItem(item: item, qty: qty);
    }).toList();
  }

  Future<void> setItemQty(String uid, MenuItemData item, int qty) async {
    final ref = _cartCol(uid).doc(item.id);
    if (qty <= 0) {
      await ref.delete();
    } else {
      await ref.set({'item': item.toMap(), 'qty': qty});
    }
  }

  Future<void> increment(String uid, MenuItemData item, int by) async {
    print('?? CartRepository.increment:');
    print('   UID: $uid');
    print('   Item: ${item.name} (${item.id})');
    print('   By: $by');
    print('   Path: users/$uid/cart/${item.id}');
    
    final ref = _cartCol(uid).doc(item.id);
    
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        int qty = (snap.data()?['qty'] as num?)?.toInt() ?? 0;
        qty += by;
        
        print('   Current qty: ${qty - by}, New qty: $qty');
        
        if (qty <= 0) {
          tx.delete(ref);
          print('   Action: DELETE');
        } else {
          tx.set(ref, {'item': item.toMap(), 'qty': qty});
          print('   Action: SET qty=$qty');
        }
      });
      
      print('? Cart transaction successful');
    } catch (e) {
      print('? Cart transaction failed: $e');
      rethrow;
    }
  }

  Future<void> clear(String uid) async {
    final qs = await _cartCol(uid).get();
    for (final d in qs.docs) {
      await d.reference.delete();
    }
  }

  Future<Map<String, String>> placeOrder(
    String uid,
    List<CartItem> items,
    double total, {
    required Map<String, dynamic> shippingAddress,
    required String paymentMethod,
    int? shippingFee,
    double? deliveryDistance,
    Map<String, double>? coordinates, // Koordinat yang sudah di-geocode (opsional)
  }) async {
    final doc = _orderCol(uid).doc();
    final code = randomAlphaNumeric(6).toUpperCase();
    
    // Ambil data user untuk pelengkap jika diperlukan
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    
    // Pastikan shippingAddress sudah dalam format lengkap
    final recipientName = shippingAddress['name'] as String? ?? 
                          userData['name'] as String? ?? 'Customer';
    final recipientPhone = shippingAddress['phone'] as String? ?? 
                           userData['phone'] as String? ?? '-';
    
    // Geocode alamat pengiriman untuk route optimization
    final address = shippingAddress['address'] as String? ?? 
                    shippingAddress['detail'] as String? ?? '';
    Map<String, double>? coords = coordinates; // Gunakan koordinat yang sudah di-cache jika ada
    
    // Hanya geocode jika koordinat belum ada
    if (coords == null && address.isNotEmpty) {
      try {
        // Coba geocode dengan alamat lengkap
        coords = await GeocodingService.getCoordinates(address);
        print('? Geocoding berhasil: ${coords?['latitude']}, ${coords?['longitude']}');
      } catch (e) {
        print('? Geocoding error: $e');
        // Continue without coordinates - order tetap dibuat
      }
    } else if (coords != null) {
      print('? Menggunakan koordinat cache: ${coords['latitude']}, ${coords['longitude']}');
    }
    
    // Normalize shippingAddress ke format baru yang lengkap
    final normalizedShippingAddress = {
      'name': recipientName,
      'phone': recipientPhone,
      'address': address,
      'latitude': coords?['latitude'],
      'longitude': coords?['longitude'],
      // Simpan juga data lama untuk backward compatibility
      if (shippingAddress['id'] != null) 'id': shippingAddress['id'],
      if (shippingAddress['title'] != null) 'title': shippingAddress['title'],
      if (shippingAddress['detail'] != null) 'detail': shippingAddress['detail'],
    };
    
    await doc.set({
      'id': doc.id,
      'userId': uid,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'total': total,
      'items': items
          .map((e) => {
                'id': e.item.id,
                'name': e.item.name,
                'price': e.item.price,
                'qty': e.qty,
              })
          .toList(),
      'shippingAddress': normalizedShippingAddress,
      'paymentMethod': paymentMethod,
      'status': 'pending',
      'paymentStatus': 'unpaid',
      // Koordinat di root level untuk route optimization & query
      'latitude': coords?['latitude'] ?? 0,
      'longitude': coords?['longitude'] ?? 0,
      'address': address, // Alamat lengkap untuk display & geocoding
      // Data ongkir dinamis
      'shippingFee': shippingFee ?? 0,
      'deliveryDistance': deliveryDistance ?? 0.0,
    });

    // kosongkan cart
    await clear(uid);
    
    // Return order ID dan code untuk payment
    return {'orderId': doc.id, 'orderCode': code};
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersStream(String uid) =>
      _orderCol(uid).snapshots();

  Stream<List<CartItem>> cartStream(String uid) => _cartCol(uid).snapshots().map(
        (snap) => snap.docs.map((d) {
          final data = d.data();
          return CartItem(
            item: MenuItemData.fromMap(data['item'] as Map<String, dynamic>),
            qty: (data['qty'] as num).toInt(),
          );
        }).toList(),
      );
}
