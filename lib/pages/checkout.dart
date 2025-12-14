import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../utils/phone_formatter.dart';
import '../service/midtrans_service.dart';
import '../service/distance_calculator.dart' as dist_calc;
import '../service/geocoding_service.dart';
import '../config/delivery_config.dart';
import 'pick_location_page.dart';
import 'qris_payment_page.dart';

typedef OnCheckoutCallback =
    Future<Map<String, String>> Function(
      double total,
      Map<String, dynamic> address,
      String paymentMethod, {
      int? shippingFee,
      double? deliveryDistance,
      Map<String, double>? coordinates, // Koordinat yang sudah di-geocode
    });

class CheckoutPage extends StatefulWidget {
  final List<CartItem> items;
  final OnCheckoutCallback onCheckout;

  const CheckoutPage({
    super.key,
    required this.items,
    required this.onCheckout,
  });

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
  
  // State untuk ongkir dinamis
  int _shippingFee = DeliveryConfig.defaultFee;
  double? _deliveryDistance; // dalam km
  String? _deliveryDistanceLabel;
  bool _isCalculatingShipping = false;
  bool _isOutOfRange = false;
  Map<String, double>? _cachedCoordinates; // Cache koordinat untuk hindari geocoding ulang

  int get _subtotal =>
      widget.items.fold(0, (p, e) => p + (e.item.price * e.qty));

  // Ongkir gratis jika subtotal >= minimum
  int get _finalShippingFee => _subtotal >= DeliveryConfig.freeShippingMinimum ? 0 : _shippingFee;

  int get _total => _subtotal + _finalShippingFee;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  /// Hitung ongkir berdasarkan jarak alamat yang dipilih
  Future<void> _calculateShippingFee(String addressId) async {
    setState(() {
      _isCalculatingShipping = true;
      _isOutOfRange = false;
    });
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      // Ambil data alamat
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .doc(addressId)
          .get();
      
      if (!snap.exists) return;
      
      final addressDetail = snap.data()!['detail'] as String;
      
      // Geocoding alamat tujuan
      final coords = await GeocodingService.getCoordinates(addressDetail);
      
      if (coords == null) {
        // Gagal geocoding, gunakan default fee
        setState(() {
          _shippingFee = DeliveryConfig.defaultFee;
          _deliveryDistance = null;
          _deliveryDistanceLabel = 'Estimasi';
          _isCalculatingShipping = false;
        });
        return;
      }
      
      // Hitung jarak dari toko
      final distance = dist_calc.DistanceCalculator.calculateDistance(
        DeliveryConfig.storeLat,
        DeliveryConfig.storeLon,
        coords['latitude']!,
        coords['longitude']!,
      );
      
      // Cache koordinat untuk digunakan saat checkout (hindari geocoding ulang)
      _cachedCoordinates = coords;
      
      // Check apakah dalam jangkauan
      if (!DeliveryConfig.isWithinRange(distance)) {
        setState(() {
          _isOutOfRange = true;
          _deliveryDistance = distance;
          _deliveryDistanceLabel = DeliveryConfig.formatDistance(distance);
          _isCalculatingShipping = false;
        });
        return;
      }
      
      // Hitung biaya ongkir
      final fee = DeliveryConfig.calculateFee(distance);
      
      setState(() {
        _shippingFee = fee;
        _deliveryDistance = distance;
        _deliveryDistanceLabel = DeliveryConfig.formatDistance(distance);
        _isCalculatingShipping = false;
      });
    } catch (e) {
      print('Error calculating shipping: $e');
      setState(() {
        _shippingFee = DeliveryConfig.defaultFee;
        _deliveryDistance = null;
        _deliveryDistanceLabel = 'Estimasi';
        _isCalculatingShipping = false;
      });
    }
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
    final total = _total;
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
                            Text(
                              it.item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '1x Rp ${_rp(it.item.price)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${_rp(it.item.price * it.qty)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                const Divider(),
                _RowSpaced('Subtotal', 'Rp ${_rp(_subtotal)}'),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ongkos Kirim',
                          style: TextStyle(fontSize: 13),
                        ),
                        if (_deliveryDistanceLabel != null && !_isCalculatingShipping)
                          Text(
                            _deliveryDistanceLabel!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    _isCalculatingShipping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF7A00),
                            ),
                          )
                        : Text(
                            _finalShippingFee == 0 ? 'GRATIS' : 'Rp ${_rp(_finalShippingFee)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _finalShippingFee == 0 ? Colors.green : Colors.black,
                            ),
                          ),
                  ],
                ),
                if (_isOutOfRange)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Alamat di luar jangkauan pengiriman (maks ${DeliveryConfig.maxDeliveryDistance} km)',
                            style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_finalShippingFee > 0 && _subtotal < DeliveryConfig.freeShippingMinimum)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Belanja min Rp ${_rp(DeliveryConfig.freeShippingMinimum)} untuk GRATIS ongkir',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const Divider(),
                const _RowSpaced('Total', '', emphasize: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Rp ${_rp(total)}',
                    style: const TextStyle(
                      color: Color(0xFFFF7A00),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                          hintStyle: const TextStyle(color: Colors.grey),
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
                        inputFormatters: [PhoneNumberFormatter()],
                        decoration: InputDecoration(
                          labelText: 'No. Telepon Penerima',
                          hintText: '+62 8xx-xxxx-xxxx',
                          hintStyle: const TextStyle(color: Colors.grey),
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
                        // Hitung ongkir untuk alamat pertama
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _calculateShippingFee(docs.first.id);
                        });
                      }
                      return Column(
                        children: [
                          if (docs.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: _inputDec(selected: false),
                              child: const Text(
                                'Belum ada alamat. Tambah alamat baru.',
                              ),
                            )
                          else
                            ...docs.map((d) {
                              final selected = d.id == _selectedAddrId;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedAddrId = d.id);
                                  // Hitung ulang ongkir saat alamat berubah
                                  _calculateShippingFee(d.id);
                                },
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
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              d['detail'] as String? ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                final recipientPhoneFormatted = _recipientPhoneController.text
                    .trim();
                final recipientPhone = PhoneNumberFormatter.cleanPhoneNumber(
                  recipientPhoneFormatted,
                );

                if (recipientName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama penerima harus diisi')),
                  );
                  return;
                }
                if (recipientPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No. telepon penerima harus diisi'),
                    ),
                  );
                  return;
                }

                if (_selectedAddrId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pilih alamat terlebih dahulu'),
                    ),
                  );
                  return;
                }
                
                // Validasi jarak pengiriman
                if (_isOutOfRange) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Alamat di luar jangkauan pengiriman (maks ${DeliveryConfig.maxDeliveryDistance} km)',
                      ),
                      backgroundColor: Colors.red,
                    ),
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
                  // Jika payment method adalah QRIS, generate QR Code via Midtrans
                  if (_payment == 'qris') {
                    final midtrans = MidtransService();
                    final orderId = 'ORDER-${DateTime.now().millisecondsSinceEpoch}';
                    
                    // Format items untuk Midtrans - harus include semua termasuk ongkir
                    final items = widget.items.map((item) => {
                      'id': item.item.id,
                      'name': item.item.name,
                      'price': item.item.price,
                      'qty': item.qty,
                    }).toList();
                    
                    // Tambahkan ongkir sebagai item jika ada
                    if (_finalShippingFee > 0) {
                      items.add({
                        'id': 'SHIPPING',
                        'name': 'Ongkos Kirim${_deliveryDistanceLabel != null ? " ($_deliveryDistanceLabel)" : ""}',
                        'price': _finalShippingFee,
                        'qty': 1,
                      });
                    }
                    
                    final qrisData = await midtrans.generateQRIS(
                      orderId: orderId,
                      grossAmount: total,
                      customerName: recipientName,
                      customerEmail: 'customer@katsuchip.com', // Default email jika tidak ada
                      customerPhone: recipientPhone,
                      items: MidtransService.formatItems(items),
                    );
                    
                    // Tutup loading
                    if (!mounted) return;
                    Navigator.pop(context);
                    
                    if (qrisData == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal generate QRIS. Silakan coba lagi.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Proses checkout DULU untuk create order di Firestore
                    final orderResult = await widget.onCheckout(
                      total.toDouble(),
                      addr,
                      _payment!,
                      shippingFee: _finalShippingFee,
                      deliveryDistance: _deliveryDistance,
                      coordinates: _cachedCoordinates,
                    );
                    
                    // Gunakan orderId dari hasil placeOrder (bukan generate sendiri)
                    final realOrderId = orderResult['orderId']!;
                    
                    // Sekarang baru simpan QRIS data ke order yang sudah ada
                    try {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .collection('orders')
                            .doc(realOrderId) // Gunakan orderId yang benar
                            .update({
                          'qrisData': {
                            'qr_code_url': qrisData['qr_code_url'],
                            'expiry_time': qrisData['expiry_time'],
                            'transaction_id': qrisData['transaction_id'],
                          },
                        });
                      }
                    } catch (e) {
                      print('Error saving QRIS data: $e');
                      // Tidak fatal, order tetap tersimpan meski QRIS data gagal disave
                    }
                    
                    // Tampilkan halaman QRIS Payment
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QRISPaymentPage(
                          qrisData: qrisData,
                          totalAmount: total,
                          orderId: realOrderId, // Gunakan orderId yang benar
                          onPaymentConfirmed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );                                                          
                    return; // Keluar dari fungsi, jangan proses checkout lagi
                  }
                  
                  // Proses checkout untuk payment method selain QRIS
                  final orderResult = await widget.onCheckout(
                    total.toDouble(),
                    addr,
                    _payment!,
                    shippingFee: _finalShippingFee,
                    deliveryDistance: _deliveryDistance,
                    coordinates: _cachedCoordinates,
                  );

                  // Update status pesanan ke "menunggu" untuk transfer bank
                  // (status pending hanya untuk QRIS yang belum bayar)
                  try {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      final realOrderId = orderResult['orderId']!;
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .collection('orders')
                          .doc(realOrderId)
                          .update({
                        'status': 'menunggu', // Ubah status ke menunggu agar admin bisa proses
                        'paymentStatus': 'paid', // Transfer bank dianggap sudah bayar
                      });
                    }
                  } catch (e) {
                    print('Error updating order status: $e');
                  }

                  // Tutup loading
                  if (!mounted) return;
                  Navigator.pop(context);

                  // Tampilkan dialog sukses
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Pesanan Berhasil',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pesanan Anda telah dibuat!',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Penerima: $recipientName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Telepon: $recipientPhone',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Pembayaran:',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Rp ${_rp(total)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFF7A00),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text(
                                      'Metode: ',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      _payment!.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Silakan lakukan pembayaran sesuai metode yang dipilih. '
                            'Pesanan akan diproses setelah pembayaran dikonfirmasi oleh admin.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );

                  // Kembali ke halaman utama dan pindah ke tab Riwayat
                  if (!mounted) return;
                  Navigator.pop(
                    context,
                    true,
                  ); // return true untuk switch ke tab Riwayat
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
                  borderRadius: BorderRadius.circular(12),
                ),
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
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .count()
        .get();
    final count = countSnap.count ?? 0;
    if (count >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maksimal 5 alamat')));
      return;
    }

    // Open map picker
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (ctx) => const PickLocationPage()),
    );

    if (result == null) return; // User cancelled

    final detailC = TextEditingController(text: result['address'] as String);
    final selectedLocation = result['position'] as LatLng;

    if (!mounted) return;

    // Then show title dialog
    final titleC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Alamat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                labelText: 'Judul (Rumah/Kantor)',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Color(0xFFFF7A00),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Lokasi dipilih:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detailC.text, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final title = titleC.text.trim();
    final detail = detailC.text.trim();
    if (title.isEmpty || detail.isEmpty) return;

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses');
    final id = col.doc().id;
    await col.doc(id).set({
      'id': id,
      'title': title,
      'detail': detail,
      'latitude': selectedLocation.latitude,
      'longitude': selectedLocation.longitude,
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trailing!,
                    style: const TextStyle(
                      color: Color(0xFFFF7A00),
                      fontSize: 12,
                    ),
                  ),
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
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
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
  const _RowSpaced(
    this.left,
    this.right, {
    this.emphasize = false,
    this.rightColor,
  });

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
