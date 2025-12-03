import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

typedef OnCheckoutCallback = Future<void> Function(
  double total,
  Map<String, dynamic> address,
  String paymentMethod,
);

class CheckoutPage extends StatefulWidget {
  final List<CartItem> items;
  final OnCheckoutCallback onCheckout;

  const CheckoutPage({super.key, required this.items, required this.onCheckout});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? _selectedAddrId;
  String? _payment; // 'qris' | 'nagari' | 'bri' | 'mandiri'
  
  // Controllers untuk data penerima
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  bool _isLoadingUserData = true;

  int get _subtotal =>
      widget.items.fold(0, (p, e) => p + (e.item.price * e.qty));
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _recipientNameController.text = data['name'] as String? ?? '';
        _recipientPhoneController.text = data['phone'] as String? ?? '';
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoadingUserData = false);
    }
  }
  
  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _addrStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('createdAt')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final total = _subtotal; // ongkir gratis
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        title: const Text('Checkout'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ringkasan Pesanan
          _CardSection(
            title: 'Ringkasan Pesanan',
            trailing: '${widget.items.length} Item',
            child: Column(
              children: [
                for (final it in widget.items) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('1x Rp ${_rp(it.item.price)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Text('Rp ${_rp(it.item.price * it.qty)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                const Divider(),
                _RowSpaced('Subtotal', 'Rp ${_rp(_subtotal)}'),
                const _RowSpaced('Ongkos Kirim', 'GRATIS',
                    rightColor: Colors.green),
                const Divider(),
                const _RowSpaced('Total', '', emphasize: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Rp ${_rp(total)}',
                      style: const TextStyle(
                          color: Color(0xFFFF7A00),
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Data Penerima
          _CardSection(
            title: 'Data Penerima',
            child: _isLoadingUserData
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      TextField(
                        controller: _recipientNameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Penerima',
                          hintText: 'Masukkan nama penerima',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _recipientPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'No. Telepon Penerima',
                          hintText: 'Contoh: 081234567890',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Data ini akan diterima oleh kurir untuk proses pengiriman',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // Alamat Pengiriman
          _CardSection(
            title: 'Alamat Pengiriman',
            trailing: 'Pilih alamat tersimpan',
            child: uid == null
                ? const Text('Silakan login')
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _addrStream(uid),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      if (_selectedAddrId == null && docs.isNotEmpty) {
                        _selectedAddrId = docs.first.id;
                      }
                      return Column(
                        children: [
                          if (docs.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: _inputDec(selected: false),
                              child: const Text(
                                  'Belum ada alamat. Tambah alamat baru.'),
                            )
                          else
                            ...docs.map((d) {
                              final selected = d.id == _selectedAddrId;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedAddrId = d.id),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: _inputDec(selected: selected),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: const Color(0xFFFF7A00),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d['title'] as String? ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(d['detail'] as String? ?? '',
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => _addAddressDialog(context, uid),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFF7A00)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              foregroundColor: const Color(0xFFFF7A00),
                            ),
                            child: const Text('+ Tambah Alamat Baru'),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),

          // Metode Pembayaran
          _CardSection(
            title: 'Metode Pembayaran',
            child: Column(
              children: [
                _PayTile(
                  selected: _payment == 'nagari',
                  onTap: () => setState(() => _payment = 'nagari'),
                  // ganti path sesuai aset logo Anda
                  logoAsset: 'assets/images/payments/nagari.png',
                  label: 'Transfer Bank Nagari',
                ),
                const SizedBox(height: 10),
                _PayTile(
                  selected: _payment == 'bri',
                  onTap: () => setState(() => _payment = 'bri'),
                  logoAsset: 'assets/images/payments/bri.png',
                  label: 'Transfer Bank BRI',
                ),
                const SizedBox(height: 10),
                _PayTile(
                  selected: _payment == 'mandiri',
                  onTap: () => setState(() => _payment = 'mandiri'),
                  logoAsset: 'assets/images/payments/mandiri.png',
                  label: 'Transfer Bank Mandiri',
                ),
                const SizedBox(height: 10),
                _PayTile(
                  selected: _payment == 'qris',
                  onTap: () => setState(() => _payment = 'qris'),
                  logoAsset: 'assets/images/payments/qris.png',
                  label: 'QRIS',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Validasi data penerima
                final recipientName = _recipientNameController.text.trim();
                final recipientPhone = _recipientPhoneController.text.trim();
                
                if (recipientName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama penerima harus diisi')),
                  );
                  return;
                }
                if (recipientPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No. telepon penerima harus diisi')),
                  );
                  return;
                }
                
                if (_selectedAddrId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pilih alamat terlebih dahulu')),
                  );
                  return;
                }
                if (_payment == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pilih metode pembayaran')),
                  );
                  return;
                }
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('addresses')
                    .doc(_selectedAddrId)
                    .get();
                if (!snap.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alamat tidak ditemukan')),
                  );
                  return;
                }
                
                // Gabungkan data penerima dengan alamat lengkap untuk geocoding
                final addressDetail = snap.data()!['detail'] as String;
                final addr = {
                  'name': recipientName,
                  'phone': recipientPhone,
                  'address': addressDetail,
                  // Data lama untuk backward compatibility
                  'id': snap.id,
                  'title': snap.data()!['title'],
                  'detail': addressDetail,
                };
                
                // Tampilkan loading
                if (!mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
                  ),
                );
                
                try {
                  // Proses checkout
                  await widget.onCheckout(total.toDouble(), addr, _payment!);
                  
                  // Tutup loading
                  if (!mounted) return;
                  Navigator.pop(context);
                  
                  // Tampilkan dialog sukses
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Pesanan Berhasil', style: TextStyle(fontSize: 18)),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pesanan Anda telah dibuat!', 
                            style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Penerima: $recipientName',
                            style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          Text('Telepon: $recipientPhone',
                            style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Pembayaran:', style: TextStyle(fontSize: 12)),
                                    Text('Rp ${_rp(total)}', 
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFF7A00),
                                        fontSize: 16,
                                      )),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Metode: ', style: TextStyle(fontSize: 12)),
                                    Text(_payment!.toUpperCase(), 
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Silakan lakukan pembayaran sesuai metode yang dipilih. '
                            'Pesanan akan diproses setelah pembayaran dikonfirmasi oleh admin.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  
                  // Kembali ke halaman utama dan pindah ke tab Riwayat
                  if (!mounted) return;
                  Navigator.pop(context, true); // return true untuk switch ke tab Riwayat
                } catch (e) {
                  // Tutup loading jika ada
                  if (!mounted) return;
                  Navigator.pop(context);
                  
                  // Tampilkan error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membuat pesanan: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Buat Pesanan'),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _inputDec({required bool selected}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: selected ? const Color(0xFFFF7A00) : Colors.black12,
        width: selected ? 1.6 : 1,
      ),
    );
  }

  Future<void> _addAddressDialog(BuildContext context, String uid) async {
    final countSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('addresses').count().get();
    final count = countSnap.count ?? 0;
    if (count >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 5 alamat')),
      );
      return;
    }

    final titleC = TextEditingController();
    final detailC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Alamat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Judul (Rumah/Kantor)')),
            const SizedBox(height: 8),
            TextField(controller: detailC, maxLines: 3, decoration: const InputDecoration(labelText: 'Alamat lengkap')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;

    final title = titleC.text.trim();
    final detail = detailC.text.trim();
    if (title.isEmpty || detail.isEmpty) return;

    final col = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('addresses');
    final id = col.doc().id;
    await col.doc(id).set({
      'id': id,
      'title': title,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => _selectedAddrId = id);
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? trailing;
  const _CardSection({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (trailing != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(trailing!,
                      style: const TextStyle(
                          color: Color(0xFFFF7A00), fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PayTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String logoAsset;
  final String label; // optional caption
  const _PayTile({
    required this.selected,
    required this.onTap,
    required this.logoAsset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFFF7A00) : Colors.black12,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Image.asset(logoAsset, height: 20, fit: BoxFit.contain),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: const Color(0xFFFF7A00),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowSpaced extends StatelessWidget {
  final String left;
  final String right;
  final bool emphasize;
  final Color? rightColor;
  const _RowSpaced(this.left, this.right,
      {this.emphasize = false, this.rightColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(left)),
          Text(
            right,
            style: TextStyle(
              color: rightColor,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

String _rp(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    b.write(s[i]);
    if (idx > 1 && idx % 3 == 1) b.write('.');
  }
  return b.toString();
}