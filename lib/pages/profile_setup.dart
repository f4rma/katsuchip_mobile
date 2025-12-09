import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../utils/error_handler.dart';
import '../utils/phone_formatter.dart';
import 'pick_location_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _phone = TextEditingController();
  final _address = TextEditingController();
  LatLng? _selectedLocation;
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          children: [
            const SizedBox(height: 12),
            // Logo
            Center(
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            // Salam
            const Text(
              'Selamat datang di KatsuChip\nSilahkan Lengkapi data berikut untuk melanjutkan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Label No. Telepon
            Row(
              children: const [
                Icon(Icons.phone, color: Color(0xFFFF7A00)),
                SizedBox(width: 8),
                Text(
                  'Nomor Telepon',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneNumberFormatter()],
              decoration: InputDecoration(
                hintText: '+62 8xx-xxxx-xxxx',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Label Alamat
            Row(
              children: const [
                Icon(Icons.home_rounded, color: Color(0xFFFF7A00)),
                SizedBox(width: 8),
                Text(
                  'Alamat Lengkap',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Map picker button
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFFF7A00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _address.text.isEmpty
                            ? 'Tap untuk pilih lokasi di peta'
                            : _address.text,
                        style: TextStyle(
                          color: _address.text.isEmpty
                              ? Colors.grey
                              : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alamat akan digunakan sebagai alamat pengiriman utama',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_saving ? 'Menyimpan...' : 'Simpan Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => PickLocationPage(
          initialPosition: _selectedLocation,
          initialAddress: _address.text.isEmpty ? null : _address.text,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result['position'] as LatLng;
        _address.text = result['address'] as String;
      });
    }
  }

  Future<void> _save() async {
    final phoneFormatted = _phone.text.trim();
    final address = _address.text.trim();

    if (phoneFormatted.isEmpty ||
        address.isEmpty ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mohon lengkapi Nomor Telepon dan pilih Alamat di peta',
          ),
        ),
      );
      return;
    }

    // Clean phone number (remove format, keep +62xxx)
    final phone = PhoneNumberFormatter.cleanPhoneNumber(phoneFormatted);

    // Validasi nomor telepon Indonesia (+62 diikuti minimal 9 digit)
    final validPhone = RegExp(r'^\+62\d{9,13}$').hasMatch(phone);
    if (!validPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Format nomor telepon tidak valid. Harus dimulai dengan 8',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw 'User belum login';
      }

      // Update data user (phone, address di level user document)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'phone': phone,
        'address': address,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // TAMBAHKAN: Simpan juga ke subcollection addresses sebagai alamat pengiriman utama
      final addressCol = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses');
      
      final addressId = addressCol.doc().id;
      await addressCol.doc(addressId).set({
        'id': addressId,
        'title': 'Alamat Utama',
        'detail': address,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getFirestoreErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
