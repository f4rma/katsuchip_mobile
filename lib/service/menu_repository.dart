import 'package:cloud_firestore/cloud_firestore.dart';

class MenuRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('menus');

  Stream<List<Map<String, dynamic>>> streamMenus() {
    return _col.orderBy('createdAt', descending: false).snapshots().map(
      (s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }

  Future<void> addMenu({
    String? id,
    required String name,
    required int price,
    String? description,
    String? imageUrl,
    List<String>? benefits,
    int stock = 0,
    bool isAvailable = true,
  }) async {
    final doc = id != null ? _col.doc(id) : _col.doc();
    await doc.set({
      'name': name,
      'price': price,
      'description': description ?? '',
      'imageUrl': imageUrl ?? '',
      'benefits': benefits ?? <String>[],
      'stock': stock,
      'isAvailable': isAvailable,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMenu(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteMenu(String id) => _col.doc(id).delete();

  Future<void> adjustStock(String id, int by) async {
    final ref = _col.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      int stock = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
      stock += by;
      if (stock < 0) stock = 0;
      tx.set(ref, {
        'stock': stock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Seed 6 initial menus using local asset images if the collection is empty.
  Future<void> seedInitialMenusIfEmpty() async {
    final qs = await _col.limit(1).get();
    if (qs.docs.isNotEmpty) return;

    final now = FieldValue.serverTimestamp();
    final menus = [
      {
        'id': 'miechili',
        'name': 'Mie Katsu Chilli Oil',
        'price': 15000,
        'imageAsset': 'assets/images/miechili.jpg',
      },
      {
        'id': 'bentochili',
        'name': 'Bento Katsu Chilli Oil',
        'price': 20000,
        'imageAsset': 'assets/images/bentochili.jpg',
      },
      {
        'id': 'bentosaus',
        'name': 'Bento Katsu Spesial Saus',
        'price': 20000,
        'imageAsset': 'assets/images/bentosaus.jpg',
      },
      {
        'id': 'nasichili',
        'name': 'Nasi Katsu Chilli Oil',
        'price': 15000,
        'imageAsset': 'assets/images/nasichili.jpg',
      },
      {
        'id': 'miespesial',
        'name': 'Mi Goreng Spesial Katsu',
        'price': 18000,
        'imageAsset': 'assets/images/miespesial.jpg',
      },
      {
        'id': 'nasisaus',
        'name': 'Nasi Katsu Spesial Saus',
        'price': 15000,
        'imageAsset': 'assets/images/nasisaus.jpg',
      },
    ];

    final batch = _db.batch();
    for (final m in menus) {
      final ref = _col.doc(m['id'] as String);
      batch.set(ref, {
        'name': m['name'],
        'price': m['price'],
        'description': '',
        'imageAsset': m['imageAsset'],
        'benefits': <String>[],
        'stock': 0,
        'isAvailable': true,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    await batch.commit();
  }
}
