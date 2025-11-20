import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import '../models/models.dart';

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
    final ref = _cartCol(uid).doc(item.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      int qty = (snap.data()?['qty'] as num?)?.toInt() ?? 0;
      qty += by;
      if (qty <= 0) {
        tx.delete(ref);
      } else {
        tx.set(ref, {'item': item.toMap(), 'qty': qty});
      }
    });
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
  }) async {
    final doc = _orderCol(uid).doc();
    final code = randomAlphaNumeric(6).toUpperCase();
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
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'status': 'pending',
      'paymentStatus': 'unpaid',
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
