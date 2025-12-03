import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_appbar_actions.dart';
import '../../utils/error_handler.dart';

class AdminKurirPage extends StatelessWidget {
  const AdminKurirPage({super.key});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Kelola Kurir'),
        actions: adminAppBarActions(context),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'kurir')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final kurirDocs = snapshot.data?.docs ?? [];

          if (kurirDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delivery_dining, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada kurir terdaftar',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Klik tombol + untuk menambah kurir baru',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: kurirDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = kurirDocs[index];
              return _KurirCard(doc: doc);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _AddKurirPage()),
          );
        },
        backgroundColor: orange,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kurir'),
      ),
    );
  }
}

class _KurirCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _KurirCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = data['name'] as String? ?? 'Kurir';
    final email = data['email'] as String? ?? '-';
    final phone = data['phone'] as String? ?? '-';
    final isActive = data['isActive'] as bool? ?? true;
    final courierProfile = data['courierProfile'] as Map<String, dynamic>?;
    final vehicleType = courierProfile?['vehicleType'] as String? ?? '-';
    final licensePlate = courierProfile?['licensePlate'] as String? ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                child: Icon(
                  Icons.delivery_dining,
                  color: isActive ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.phone,
                  label: phone,
                ),
              ),
              Expanded(
                child: _InfoRow(
                  icon: Icons.motorcycle,
                  label: vehicleType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.confirmation_number,
            label: 'Plat: $licensePlate',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _toggleActive(context, doc, !isActive),
              icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
              label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isActive ? Colors.red : Colors.green,
                side: BorderSide(color: isActive ? Colors.red : Colors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    QueryDocumentSnapshot doc,
    bool newStatus,
  ) async {
    try {
      await doc.reference.update({'isActive': newStatus});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Kurir diaktifkan' : 'Kurir dinonaktifkan'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Form Tambah Kurir (moved to bottom of file)
class _AddKurirPage extends StatefulWidget {
  const _AddKurirPage();

  @override
  State<_AddKurirPage> createState() => _AddKurirPageState();
}

class _AddKurirPageState extends State<_AddKurirPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // _passwordController dihapus - kurir akan set password saat aktivasi
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  
  bool _isLoading = false;
  // _obscurePassword dihapus - tidak ada password field lagi

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    // _passwordController.dispose() dihapus
    _phoneController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _registerKurir() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Generate unique invitation token
      final invitationToken = FirebaseFirestore.instance.collection('kurir_invitations').doc().id;
      
      // Simpan sebagai "pending approval" di collection kurir_invitations
      final invitationDoc = FirebaseFirestore.instance.collection('kurir_invitations').doc(invitationToken);
      
      await invitationDoc.set({
        'email': _emailController.text.trim(),
        // tempPassword dihapus - kurir akan set password sendiri saat aktivasi
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicleType': _vehicleController.text.trim(),
        'licensePlate': _plateController.text.trim(),
        'status': 'pending',
        'invitationToken': invitationToken,
        'tokenExpiry': DateTime.now().add(const Duration(days: 7)), // 7 hari expire
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Generate simple invitation link (custom URI scheme)
      final invitationLink = 'katsuchip://register-kurir?token=$invitationToken';

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Undangan Dibuat'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Token undangan berhasil dibuat:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          invitationToken,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFFF7A00), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Token berlaku 7 hari dan hanya bisa digunakan 1x',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih cara mengirim undangan:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            actions: [
              // Tombol WhatsApp
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final phoneNumber = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
                    final message = Uri.encodeComponent(
                      'Halo ${_nameController.text.trim()},\n\n'
                      'Selamat! Anda diundang menjadi Kurir KatsuChip! 🎉\n\n'
                      '📱 CARA REGISTRASI:\n\n'
                      '▶️ Buka aplikasi KatsuChip di HP Anda\n'
                      '▶️ Login dengan token berikut:\n\n'
                      '🔑 TOKEN: $invitationToken\n\n'
                      '(Copy token di atas, lalu paste di aplikasi KatsuChip)\n\n'
                      '📧 Email: ${_emailController.text.trim()}\n'
                      '🔒 Anda akan diminta membuat password saat aktivasi\n\n'
                      '⏰ Token berlaku 7 hari\n'
                      '✅ Hanya bisa digunakan 1x\n\n'
                      'Jika ada kendala, hubungi admin. Terima kasih!'
                    );
                    
                    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=$message');
                    
                    if (await canLaunchUrl(whatsappUri)) {
                      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Tutup dialog
                        Navigator.of(context).pop(); // Tutup form
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ Tidak bisa membuka WhatsApp'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Email
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: _emailController.text.trim(),
                      queryParameters: {
                        'subject': 'Undangan Kurir KatsuChip',
                        'body': 'Halo ${_nameController.text.trim()},\n\n'
                            'Anda diundang jadi kurir KatsuChip.\n\n'
                            'Cara Registrasi:\n'
                            '1. Download aplikasi KatsuChip\n'
                            '2. Buka aplikasi\n'
                            '3. Masukkan token di bawah saat diminta\n'
                            '4. Buat password baru saat aktivasi\n\n'
                            'Token Invitation:\n$invitationToken\n\n'
                            'Email: ${_emailController.text.trim()}\n\n'
                            'Token berlaku 7 hari.',
                      },
                    );
                    
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Tutup dialog
                        Navigator.of(context).pop(); // Tutup form
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ Tidak bisa membuka aplikasi email'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('Email', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Copy
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: invitationToken));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Token berhasil disalin!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.of(context).pop(); // Tutup dialog
                      Navigator.of(context).pop(); // Tutup form
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFirestoreErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getAuthErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Tambah Kurir Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Nama Lengkap',
              icon: Icons.person,
              validator: (v) => v?.isEmpty ?? true ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Email wajib diisi';
                if (!v!.contains('@')) return 'Email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Password dihapus - kurir akan set password saat aktivasi dengan token
            _buildTextField(
              controller: _phoneController,
              label: 'Nomor HP',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Nomor HP wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _vehicleController,
              label: 'Jenis Kendaraan (motor/mobil)',
              icon: Icons.motorcycle,
              validator: (v) => v?.isEmpty ?? true ? 'Jenis kendaraan wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _plateController,
              label: 'Plat Nomor',
              icon: Icons.confirmation_number,
              validator: (v) => v?.isEmpty ?? true ? 'Plat nomor wajib diisi' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerKurir,
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Daftarkan Kurir',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }
}
