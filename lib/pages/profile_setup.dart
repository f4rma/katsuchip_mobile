import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/error_handler.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _phone = TextEditingController();
  final _address = TextEditingController();
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
              style: TextStyle(
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Label No. Telepon
            Row(
              children: const [
                Icon(Icons.phone, color: Color(0xFFFF7A00)),
                SizedBox(width: 8),
                Text('Nomor Telepon', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Contoh: 081234567890',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                Text('Alamat Lengkap', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              maxLines: 3,
              keyboardType: TextInputType.streetAddress,
              decoration: InputDecoration(
                hintText: 'Contoh: Jl. Nenas no.21, RT 01/RW 02, Kelurahan Kampung Lapai, Kecamatan Nanggalo',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_saving ? 'Menyimpan...' : 'Simpan Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final phone = _phone.text.trim();
    final address = _address.text.trim();

    if (phone.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi Nomor Telepon dan Alamat')),
      );
      return;
    }
    // Validasi sederhana nomor telepon Indonesia
    final validPhone = RegExp(r'^(?:\+62|0)\d{8,15}$').hasMatch(phone);
    if (!validPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format nomor telepon tidak valid')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw 'User belum login';
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'phone': phone,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
