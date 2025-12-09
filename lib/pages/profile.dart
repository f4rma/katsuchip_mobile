import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../service/auth_service.dart';
import '../utils/phone_formatter.dart';
import 'pick_location_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/login'),
            child: const Text('Masuk'),
          ),
        ),
      );
    }

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final addrCol = userDoc.collection('addresses');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDoc.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final email = user.email ?? '-';
            final name = (user.displayName?.trim().isNotEmpty ?? false)
                ? user.displayName!
                : 'Pengguna';
            final phone = (data['phone'] ?? '') as String;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white.withValues(alpha: .25),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: perbesar nama & email
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18, // was 16
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13, // was 12
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Informasi Profil
                _Section(
                  title: 'Informasi Profil',
                  onEdit: () =>
                      _editProfileDialog(context, userDoc, user, name, phone),
                  child: Column(
                    children: [
                      _InfoTile(label: 'Email', value: email),
                      _InfoTile(label: 'Nama Lengkap', value: name),
                      _InfoTile(
                        label: 'Nomor Telepon',
                        value: phone.isEmpty ? '-' : phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Alamat Pengiriman
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: addrCol
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, addrSnap) {
                    final docs = addrSnap.data?.docs ?? const [];
                    return _Section(
                      title: 'Alamat Pengiriman',
                      onEdit: docs.length >= 5
                          ? null
                          : () => _addressDialog(
                              context,
                              addrCol,
                            ), // tambah alamat
                      child: Column(
                        children: [
                          if (docs.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              width: double.infinity,
                              child: const Text(
                                'Belum ada alamat. Ketuk Edit untuk menambah.',
                              ),
                            ),
                          for (final d in docs) ...[
                            _AddressTile(
                              title: d['title'] as String? ?? '',
                              detail: d['detail'] as String? ?? '',
                              onEdit: () => _addressDialog(
                                context,
                                addrCol,
                                docId: d.id,
                                current: d.data(),
                              ),
                              onDelete: () async {
                                final ok = await _confirm(
                                  context,
                                  'Hapus alamat ini?',
                                );
                                if (ok == true) {
                                  await addrCol.doc(d.id).delete();
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (docs.length >= 5)
                            const Text(
                              'Maksimal 5 alamat.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Pengaturan
                _Section(
                  title: 'Pengaturan',
                  child: Column(
                    children: [
                      _SettingRow(
                        icon: Icons.help_outline,
                        text: 'Bantuan & FAQ',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpFAQPage()),
                        ),
                      ),
                      _SettingRow(
                        icon: Icons.description_outlined,
                        text: 'Syarat & Ketentuan',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsConditionsPage()),
                        ),
                      ),
                      const Divider(height: 22),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Logout
                TextButton.icon(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ========== DIALOGS ==========
  static Future<void> _editProfileDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> userDoc,
    User user,
    String currentName,
    String currentPhone,
  ) async {
    final nameC = TextEditingController(
      text: currentName == 'Pengguna' ? '' : currentName,
    );
    final phoneC = TextEditingController(text: currentPhone);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Informasi Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneC,
              enabled: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneNumberFormatter()],
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon',
                hintText: '+62 8xx-xxxx-xxxx',
                hintStyle: TextStyle(color: Colors.grey),
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

    if (ok == true) {
      try {
        final name = nameC.text.trim();
        final phoneFormatted = phoneC.text.trim();
        final phone = PhoneNumberFormatter.cleanPhoneNumber(phoneFormatted);
        if (name.isNotEmpty) {
          await user.updateDisplayName(name);
        }
        if (phone.isNotEmpty) {
          // validasi nomor telepon Indonesia
          final isValid = RegExp(r'^\+62\d{9,13}$').hasMatch(phone);
          if (!isValid) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Format nomor telepon tidak valid'),
                ),
              );
            }
            return;
          }
          await userDoc.set({
            'phone': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil diperbarui'),
              backgroundColor: Color(0xFFFF7A00),
            ),
          );
        }
      } catch (e) {
        print('Error updating profile: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui profil: $e')),
          );
        }
      }
    }
  }

  static Future<void> _addressDialog(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> addrCol, {
    String? docId,
    Map<String, dynamic>? current,
  }) async {
    final isEdit = docId != null && current != null;
    final titleC = TextEditingController(
      text: current?['title'] as String? ?? '',
    );
    final detailC = TextEditingController(
      text: current?['detail'] as String? ?? '',
    );
    LatLng? selectedLocation;

    // Load existing coordinates if editing
    if (isEdit) {
      final lat = current['latitude'] as double?;
      final lng = current['longitude'] as double?;
      if (lat != null && lng != null) {
        selectedLocation = LatLng(lat, lng);
      }
    }

    // Batasi 5 alamat saat tambah
    if (!isEdit) {
      final snap = await addrCol.count().get();
      final count = snap.count ?? 0;
      if (count >= 5) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Maksimal 5 alamat')));
        }
        return;
      }
    }

    // Show pick location page
    if (context.mounted) {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (ctx) => PickLocationPage(
            initialPosition: selectedLocation,
            initialAddress: detailC.text.isEmpty ? null : detailC.text,
          ),
        ),
      );

      if (result != null) {
        selectedLocation = result['position'] as LatLng;
        detailC.text = result['address'] as String;
      } else {
        // User cancelled location pick
        return;
      }
    }

    if (!context.mounted) return;

    // Show title dialog
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Alamat' : 'Tambah Alamat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                labelText: 'Judul (contoh: Rumah/Kantor)',
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

    if (ok == true && selectedLocation != null) {
      final title = titleC.text.trim();
      final detail = detailC.text.trim();
      if (title.isEmpty || detail.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Judul dan alamat tidak boleh kosong'),
            ),
          );
        }
        return;
      }
      try {
        if (isEdit) {
          await addrCol.doc(docId).set({
            'title': title,
            'detail': detail,
            'latitude': selectedLocation.latitude,
            'longitude': selectedLocation.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          final id = addrCol.doc().id;
          await addrCol.doc(id).set({
            'id': id,
            'title': title,
            'detail': detail,
            'latitude': selectedLocation.latitude,
            'longitude': selectedLocation.longitude,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit
                    ? 'Alamat berhasil diperbarui'
                    : 'Alamat berhasil ditambahkan',
              ),
              backgroundColor: const Color(0xFFFF7A00),
            ),
          );
        }
      } catch (e) {
        print('Error saving address: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan alamat: $e')));
        }
      }
    }
  }

  static Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onEdit;
  const _Section({required this.title, required this.child, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), // was 14
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15, // was 14
                  ),
                ),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFFFF7A00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ), // was 11
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)), // was 13
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final String title;
  final String detail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.title,
    required this.detail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ), // was 12
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
                tooltip: 'Hapus',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(fontSize: 14)), // was 13
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _SettingRow({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.black87),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      visualDensity: const VisualDensity(vertical: -2),
    );
  }
}

// ========== HELP & FAQ PAGE ==========
class HelpFAQPage extends StatelessWidget {
  const HelpFAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        title: const Text('Bantuan & FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FAQSection(
            title: 'Pembayaran',
            items: [
              _FAQItem(
                question: 'Apa saja metode pembayaran yang tersedia?',
                answer: 'Kami menyediakan berbagai metode pembayaran:\n\n'
                    '• QRIS - Scan QR dengan aplikasi mobile banking/e-wallet apapun\n'
                    '• Transfer Bank BRI\n'
                    '• Transfer Bank Mandiri\n'
                    '• Transfer Bank Nagari\n\n'
                    'Semua pembayaran diproses secara aman melalui payment gateway Midtrans.',
              ),
              _FAQItem(
                question: 'Bagaimana cara bayar dengan QRIS?',
                answer: '1. Pilih metode pembayaran QRIS saat checkout\n'
                    '2. QR Code akan muncul di layar\n'
                    '3. Buka aplikasi mobile banking/e-wallet Anda (GoPay, OVO, Dana, dll)\n'
                    '4. Scan QR Code yang ditampilkan\n'
                    '5. Konfirmasi pembayaran\n'
                    '6. Status pesanan akan otomatis diperbarui setelah pembayaran berhasil\n\n'
                    'Catatan: QR Code berlaku selama 20 menit.',
              ),
              _FAQItem(
                question: 'Berapa lama pembayaran diproses?',
                answer: 'Pembayaran QRIS: Instan (1-5 menit)\n'
                    'Transfer Bank: 1-15 menit (tergantung bank)\n\n'
                    'Status pesanan akan otomatis diperbarui setelah pembayaran terverifikasi.',
              ),
              _FAQItem(
                question: 'Apa yang terjadi jika pembayaran gagal?',
                answer: 'Jika pembayaran gagal atau dibatalkan:\n\n'
                    '• Pesanan akan otomatis dibatalkan\n'
                    '• Dana tidak akan dipotong dari rekening Anda\n'
                    '• Anda dapat membuat pesanan baru\n\n'
                    'Untuk QRIS, jika tidak dibayar dalam 20 menit, pesanan otomatis dibatalkan.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FAQSection(
            title: 'Pesanan',
            items: [
              _FAQItem(
                question: 'Bagaimana cara memesan?',
                answer: '1. Pilih menu yang ingin dipesan\n'
                    '2. Tambahkan ke keranjang\n'
                    '3. Klik ikon keranjang di pojok kanan atas\n'
                    '4. Review pesanan Anda\n'
                    '5. Klik "Checkout"\n'
                    '6. Pilih alamat pengiriman\n'
                    '7. Pilih metode pembayaran\n'
                    '8. Konfirmasi pesanan',
              ),
              _FAQItem(
                question: 'Bagaimana cara melacak pesanan?',
                answer: 'Anda dapat melacak pesanan melalui:\n\n'
                    '1. Tab "Pesanan" di halaman utama\n'
                    '2. Klik pesanan untuk melihat detail dan status\n'
                    '3. Status akan diperbarui secara real-time:\n'
                    '   • Menunggu Pembayaran\n'
                    '   • Sedang Diproses\n'
                    '   • Sedang Diantar\n'
                    '   • Pesanan Diterima',
              ),
              _FAQItem(
                question: 'Berapa lama pesanan sampai?',
                answer: 'Estimasi waktu pengiriman:\n\n'
                    '• Proses pesanan: 15-30 menit\n'
                    '• Pengiriman: 20-45 menit (tergantung jarak)\n\n'
                    'Total estimasi: 35-75 menit dari pembayaran berhasil.',
              ),
              _FAQItem(
                question: 'Bisakah membatalkan pesanan?',
                answer: 'Ya, pesanan dapat dibatalkan jika:\n\n'
                    '• Status masih "Menunggu Pembayaran" - batalkan kapan saja\n'
                    '• Status "Sedang Diproses" - hubungi admin melalui tombol "Hubungi Penjual"\n\n'
                    'Pesanan yang sudah "Sedang Diantar" tidak dapat dibatalkan.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FAQSection(
            title: 'Pengiriman',
            items: [
              _FAQItem(
                question: 'Berapa biaya pengiriman?',
                answer: 'Ongkos kirim:\n\n'
                    '• GRATIS untuk pembelian = Rp 50.000\n'
                    '• Rp 10.000 untuk pembelian < Rp 50.000',
              ),
              _FAQItem(
                question: 'Ke mana saja area pengiriman?',
                answer: 'Saat ini kami melayani pengiriman di area Kota Padang dan sekitarnya.\n\n'
                    'Untuk area di luar jangkauan, silakan hubungi admin terlebih dahulu.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FAQSection(
            title: 'Akun',
            items: [
              _FAQItem(
                question: 'Bagaimana cara mengubah profil?',
                answer: '1. Buka tab "Profil"\n'
                    '2. Klik tombol "Edit" di bagian Informasi Profil\n'
                    '3. Ubah nama atau nomor telepon\n'
                    '4. Klik "Simpan"',
              ),
              _FAQItem(
                question: 'Bagaimana cara mengelola alamat?',
                answer: 'Menambah alamat:\n'
                    '1. Buka tab "Profil"\n'
                    '2. Di bagian "Alamat Pengiriman", klik "Edit"\n'
                    '3. Isi detail alamat dan pilih lokasi di peta\n'
                    '4. Klik "Simpan"\n\n'
                    'Menghapus alamat:\n'
                    '1. Klik icon hapus pada alamat\n'
                    '2. Konfirmasi penghapusan\n\n'
                    'Maksimal 5 alamat tersimpan.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent, size: 48, color: Color(0xFFFF7A00)),
                const SizedBox(height: 12),
                const Text(
                  'Masih Ada Pertanyaan?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hubungi kami melalui WhatsApp untuk bantuan lebih lanjut',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    // WhatsApp admin
                    final Uri whatsappUri = Uri.parse('https://wa.me/6282284519884?text=${Uri.encodeComponent('Halo Admin KatsuChip, saya butuh bantuan')}');
                    if (await canLaunchUrl(whatsappUri)) {
                      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Hubungi Admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQSection extends StatelessWidget {
  final String title;
  final List<_FAQItem> items;
  
  const _FAQSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A00),
            ),
          ),
        ),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: item,
        )),
      ],
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  
  const _FAQItem({required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFFFF7A00),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== TERMS & CONDITIONS PAGE ==========
class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        title: const Text('Syarat & Ketentuan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: '1. Ketentuan Umum',
            content: 'Dengan menggunakan aplikasi KatsuChip, Anda menyetujui untuk terikat dengan syarat dan ketentuan berikut. '
                'Jika Anda tidak setuju dengan ketentuan ini, mohon untuk tidak menggunakan layanan kami.\n\n'
                'KatsuChip berhak untuk mengubah syarat dan ketentuan ini sewaktu-waktu tanpa pemberitahuan terlebih dahulu. '
                'Perubahan akan berlaku segera setelah dipublikasikan di aplikasi.',
          ),
          _buildSection(
            title: '2. Pendaftaran dan Akun',
            content: '• Anda harus mendaftar dan membuat akun untuk menggunakan layanan kami\n'
                '• Informasi yang Anda berikan harus akurat dan terkini\n'
                '• Anda bertanggung jawab menjaga kerahasiaan akun dan password\n'
                '• Anda bertanggung jawab atas semua aktivitas yang terjadi di akun Anda\n'
                '• Kami berhak menonaktifkan akun yang melanggar ketentuan',
          ),
          _buildSection(
            title: '3. Pemesanan',
            content: '• Semua pesanan tergantung pada ketersediaan stok\n'
                '• Kami berhak menolak atau membatalkan pesanan jika terjadi masalah pembayaran, penipuan, atau ketidaktersediaan produk\n'
                '• Harga yang ditampilkan sudah final dan termasuk pajak (jika ada)\n'
                '• Ongkos kirim akan dihitung otomatis saat checkout\n'
                '• Pesanan yang sudah dikonfirmasi tidak dapat diubah',
          ),
          _buildSection(
            title: '4. Pembayaran',
            content: '• Pembayaran dilakukan melalui payment gateway Midtrans yang aman\n'
                '• Metode pembayaran yang tersedia: QRIS, Transfer Bank (BRI, Mandiri, Nagari)\n'
                '• Pembayaran QRIS harus diselesaikan dalam 20 menit\n'
                '• Transfer bank harus diselesaikan sesuai instruksi yang diberikan\n'
                '• Pesanan akan diproses setelah pembayaran terverifikasi\n'
                '• Kami tidak menyimpan informasi kartu kredit/debit Anda',
          ),
          _buildSection(
            title: '5. Pengiriman',
            content: '• Pengiriman hanya tersedia di area Kota Padang dan sekitarnya\n'
                '• Ongkos kirim GRATIS untuk pembelian = Rp 50.000\n'
                '• Ongkos kirim Rp 10.000 untuk pembelian < Rp 50.000\n'
                '• Estimasi waktu pengiriman: 35-75 menit dari pembayaran berhasil\n'
                '• Waktu pengiriman dapat berbeda tergantung kondisi lalu lintas dan cuaca\n'
                '• Pastikan alamat pengiriman yang Anda berikan akurat dan lengkap',
          ),
          _buildSection(
            title: '6. Pembatalan dan Pengembalian',
            content: '• Pesanan dapat dibatalkan jika status masih "Menunggu Pembayaran"\n'
                '• Pesanan yang sudah dibayar dan sedang diproses dapat dibatalkan dengan menghubungi admin\n'
                '• Pesanan yang sudah dalam pengiriman tidak dapat dibatalkan\n'
                '• Pengembalian dana (refund) akan diproses maksimal 7 hari kerja\n'
                '• Produk makanan yang sudah dikirim tidak dapat dikembalikan kecuali ada kerusakan atau kesalahan produk',
          ),
          _buildSection(
            title: '7. Kebijakan Privasi',
            content: '• Kami menghormati privasi Anda dan melindungi data pribadi\n'
                '• Data yang kami kumpulkan: nama, email, nomor telepon, alamat pengiriman\n'
                '• Data digunakan untuk memproses pesanan dan meningkatkan layanan\n'
                '• Kami tidak akan membagikan data Anda kepada pihak ketiga tanpa izin\n'
                '• Data pembayaran dienkripsi dan diproses oleh payment gateway Midtrans\n'
                '• Anda dapat menghapus akun kapan saja dengan menghubungi admin',
          ),
          _buildSection(
            title: '8. Tanggung Jawab',
            content: '• Kami berusaha memberikan layanan terbaik, namun tidak menjamin 100% tanpa kesalahan\n'
                '• Kami tidak bertanggung jawab atas kerugian yang disebabkan oleh:\n'
                '  - Kesalahan informasi yang Anda berikan\n'
                '  - Gangguan teknis atau internet\n'
                '  - Force majeure (bencana alam, kerusuhan, dll)\n'
                '• Kualitas makanan dijamin fresh dan higienis sesuai standar kesehatan\n'
                '• Jika ada keluhan, segera hubungi kami maksimal 24 jam setelah pengiriman',
          ),
          _buildSection(
            title: '9. Hak Kekayaan Intelektual',
            content: '• Semua konten di aplikasi (logo, desain, teks, gambar) adalah milik KatsuChip\n'
                '• Dilarang menggunakan, menyalin, atau mendistribusikan konten tanpa izin tertulis\n'
                '• Pelanggaran akan ditindak sesuai hukum yang berlaku',
          ),
          _buildSection(
            title: '10. Hukum yang Berlaku',
            content: 'Syarat dan ketentuan ini diatur oleh dan ditafsirkan sesuai dengan hukum yang berlaku di Negara Republik Indonesia. '
                'Setiap perselisihan yang timbul akan diselesaikan melalui musyawarah atau jalur hukum di pengadilan yang berwenang.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline, size: 40, color: Color(0xFFFF7A00)),
                const SizedBox(height: 12),
                const Text(
                  'Terakhir diperbarui: 7 Desember 2025',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7A00),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dengan melanjutkan menggunakan aplikasi ini, Anda dianggap telah membaca, memahami, dan menyetujui syarat dan ketentuan yang berlaku.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A00),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
