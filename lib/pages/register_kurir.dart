import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/error_handler.dart';

class RegisterKurirPage extends StatefulWidget {
  final String? invitationToken;
  
  const RegisterKurirPage({super.key, this.invitationToken});

  @override
  State<RegisterKurirPage> createState() => _RegisterKurirPageState();
}

class _RegisterKurirPageState extends State<RegisterKurirPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  // Invitation data
  Map<String, dynamic>? _invitationData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _validateInvitation();
  }

  Future<void> _validateInvitation() async {
    if (widget.invitationToken == null || widget.invitationToken!.isEmpty) {
      setState(() {
        _errorMessage = 'Link invitation tidak valid. Hubungi admin untuk mendapatkan link baru.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Ambil invitation dari Firestore berdasarkan token
      final invitationDoc = await FirebaseFirestore.instance
          .collection('kurir_invitations')
          .doc(widget.invitationToken)
          .get();

      if (!invitationDoc.exists) {
        setState(() {
          _errorMessage = 'Link invitation tidak ditemukan atau sudah digunakan.';
          _isLoading = false;
        });
        return;
      }

      final data = invitationDoc.data()!;

      // Cek apakah sudah digunakan
      if (data['status'] != 'pending') {
        setState(() {
          _errorMessage = 'Link invitation sudah digunakan.';
          _isLoading = false;
        });
        return;
      }

      // Cek apakah expired (7 hari)
      final tokenExpiry = (data['tokenExpiry'] as Timestamp).toDate();
      if (DateTime.now().isAfter(tokenExpiry)) {
        setState(() {
          _errorMessage = 'Link invitation sudah kadaluarsa. Hubungi admin untuk mendapatkan link baru.';
          _isLoading = false;
        });
        return;
      }

      // Invitation valid
      setState(() {
        _invitationData = data;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat validasi invitation: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invitationData == null) return;

    setState(() => _isLoading = true);

    try {
      final email = _invitationData!['email'];
      final newPassword = _newPasswordController.text;

      // 1. Buat akun Firebase Auth dengan password BARU
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: newPassword,
      );

      final uid = credential.user!.uid;

      // 2. Buat user document di Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'name': _invitationData!['name'],
        'role': 'kurir',
        'phone': _invitationData!['phone'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'courierProfile': {
          'vehicleType': _invitationData!['vehicleType'],
          'licensePlate': _invitationData!['licensePlate'],
        },
      });

      // 3. Hapus invitation (sudah digunakan)
      await FirebaseFirestore.instance
          .collection('kurir_invitations')
          .doc(widget.invitationToken)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrasi berhasil! Silakan login'),
            backgroundColor: Colors.green,
          ),
        );

        // Sign out dan kembali ke login
        await FirebaseAuth.instance.signOut();
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getAuthErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFirestoreErrorMessage(e)),
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
        title: const Text('Registrasi Kurir'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 80, color: Colors.red),
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Kembali'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.delivery_dining, size: 80, color: orange),
                        const SizedBox(height: 24),
                        const Text(
                          'Selamat Datang!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Halo, ${_invitationData!['name']}!\nBuat password baru untuk akun Anda.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 32),
                        
                        // Info Email (readonly)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email Anda:',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _invitationData!['email'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Baru
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            labelText: 'Password Baru',
                            hintText: 'Minimal 6 karakter',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password tidak boleh kosong';
                            }
                            if (value.length < 6) {
                              return 'Password minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Konfirmasi Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Konfirmasi Password',
                            hintText: 'Ulangi password baru',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Konfirmasi password tidak boleh kosong';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Password tidak cocok';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Daftar',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
