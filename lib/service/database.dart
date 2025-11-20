import 'package:cloud_firestore/cloud_firestore.dart';

// method simpan data ke Firestore
class DatabaseMethod {
  Future<void> addPerlengkapan(
      // map data yang akan disimpan
      Map<String, dynamic> perlengkapanInfoMap,
      // id unik untuk dokumen
      String id,
  ) async {
    return await FirebaseFirestore.instance
        .collection('PerlengkapanPMR')
        .doc(id)
        .set(perlengkapanInfoMap);
  }

  Future<void> deletePerlengkapan(String id) async {
    return await FirebaseFirestore.instance
        .collection('PerlengkapanPMR')
        .doc(id)
        .delete();
  }

  Future<void> updatePerlengkapan(
      Map<String, dynamic> perlengkapanInfoMap,
      String id,
  ) async {
    return await FirebaseFirestore.instance
        .collection('PerlengkapanPMR')
        .doc(id)
        .update(perlengkapanInfoMap);
  }

  Future<List<Map<String, dynamic>>> getPerlengkapanList() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('PerlengkapanPMR').get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }
}
