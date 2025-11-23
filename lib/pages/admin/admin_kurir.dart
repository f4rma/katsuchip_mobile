import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_appbar_actions.dart';

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
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _registerKurir() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create Firebase Auth user
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      // 2. Create Firestore document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': 'kurir',
        'phone': _phoneController.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'courierProfile': {
          'vehicleType': _vehicleController.text.trim(),
          'licensePlate': _plateController.text.trim(),
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kurir ${_nameController.text} berhasil didaftarkan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal mendaftarkan kurir';
      if (e.code == 'email-already-in-use') {
        message = 'Email sudah digunakan';
      } else if (e.code == 'weak-password') {
        message = 'Password terlalu lemah (min 6 karakter)';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock,
              obscureText: true,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Password wajib diisi';
                if (v!.length < 6) return 'Password minimal 6 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
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
