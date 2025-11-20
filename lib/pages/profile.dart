import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/auth_service.dart';

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
            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
            child: const Text('Masuk'),
          ),
        ),
      );
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final addrCol = userDoc.collection('addresses');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDoc.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final email = user.email ?? '-';
            final name = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName! : 'Pengguna';
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
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
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
                  onEdit: () => _editProfileDialog(context, userDoc, user, name, phone),
                  child: Column(
                    children: [
                      _InfoTile(label: 'Email', value: email),
                      _InfoTile(label: 'Nama Lengkap', value: name),
                      _InfoTile(label: 'Nomor Telepon', value: phone.isEmpty ? '-' : phone),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Alamat Pengiriman
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: addrCol.orderBy('createdAt', descending: false).snapshots(),
                  builder: (context, addrSnap) {
                    final docs = addrSnap.data?.docs ?? const [];
                    return _Section(
                      title: 'Alamat Pengiriman',
                      onEdit: docs.length >= 5
                          ? null
                          : () => _addressDialog(context, addrCol), // tambah alamat
                      child: Column(
                        children: [
                          if (docs.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              width: double.infinity,
                              child: const Text('Belum ada alamat. Ketuk Edit untuk menambah.'),
                            ),
                          for (final d in docs) ...[
                            _AddressTile(
                              title: d['title'] as String? ?? '',
                              detail: d['detail'] as String? ?? '',
                              onEdit: () => _addressDialog(context, addrCol, docId: d.id, current: d.data()),
                              onDelete: () async {
                                final ok = await _confirm(context, 'Hapus alamat ini?');
                                if (ok == true) await addrCol.doc(d.id).delete();
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (docs.length >= 5)
                            const Text('Maksimal 5 alamat.', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
                    children: const [
                      _SettingRow(icon: Icons.notifications_none, text: 'Notifikasi'),
                      _SettingRow(icon: Icons.help_outline, text: 'Bantuan & FAQ'),
                      _SettingRow(icon: Icons.description_outlined, text: 'Syarat & Ketentuan'),
                      Divider(height: 22),
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
                  label: const Text('Logout', style: TextStyle(color: Colors.red)),
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
    final nameC = TextEditingController(text: currentName == 'Pengguna' ? '' : currentName);
    final phoneC = TextEditingController(text: currentPhone);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Informasi Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
            const SizedBox(height: 8),
            TextField(
              controller: phoneC,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor Telepon'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );

    if (ok == true) {
      final name = nameC.text.trim();
      final phone = phoneC.text.trim();
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      if (phone.isNotEmpty) {
        // validasi sederhana
        final isValid = RegExp(r'^(?:\+62|0)\d{8,15}$').hasMatch(phone);
        if (!isValid) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format nomor telepon tidak valid')));
          }
          return;
        }
        await userDoc.set({'phone': phone, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
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
    final titleC = TextEditingController(text: current?['title'] as String? ?? '');
    final detailC = TextEditingController(text: current?['detail'] as String? ?? '');

    // Batasi 5 alamat saat tambah
    if (!isEdit) {
      final snap = await addrCol.count().get();
      final count = snap.count ?? 0;
      if (count >= 5) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimal 5 alamat')));
        }
        return;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Alamat' : 'Tambah Alamat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Judul (contoh: Rumah/Kantor)')),
            const SizedBox(height: 8),
            TextField(
              controller: detailC,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );

    if (ok == true) {
      final title = titleC.text.trim();
      final detail = detailC.text.trim();
      if (title.isEmpty || detail.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan alamat tidak boleh kosong')));
        }
        return;
      }
      if (isEdit) {
        await addrCol.doc(docId).set({
          'title': title,
          'detail': detail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final id = addrCol.doc().id;
        await addrCol.doc(id).set({
          'id': id,
          'title': title,
          'detail': detail,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static Future<bool?> _confirm(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
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
                  child: const Text('Edit', style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.w600)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)), // was 11
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), // was 12
              const Spacer(),
              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit, tooltip: 'Edit'),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete, tooltip: 'Hapus'),
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
  const _SettingRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.black87),
      title: Text(text),
      contentPadding: EdgeInsets.zero,
      onTap: () {},
      visualDensity: const VisualDensity(vertical: -2),
    );
  }
}