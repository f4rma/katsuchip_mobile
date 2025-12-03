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
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false; // Changed: start with false untuk tampilkan form token
  bool _tokenValidated = false; // New: flag untuk cek token sudah divalidasi
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  // Invitation data
  Map<String, dynamic>? _invitationData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Jika token dari URL parameter, validasi otomatis
    if (widget.invitationToken != null && widget.invitationToken!.isNotEmpty) {
      _tokenController.text = widget.invitationToken!;
      _validateInvitation();
    }
  }

  Future<void> _validateInvitation() async {
    final token = _tokenController.text.trim();
    
    print('🔍 Validating token: $token');
    
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Token invitation tidak boleh kosong.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ambil invitation dari Firestore berdasarkan token
      print('📡 Fetching invitation from Firestore...');
      final invitationDoc = await FirebaseFirestore.instance
          .collection('kurir_invitations')
          .doc(token)
          .get();

      print('📄 Document exists: ${invitationDoc.exists}');

      if (!invitationDoc.exists) {
        print('❌ Token not found in Firestore');
        setState(() {
          _errorMessage = 'Token invitation tidak ditemukan atau sudah digunakan.';
          _isLoading = false;
        });
        return;
      }

      final data = invitationDoc.data()!;
      print('✅ Invitation data: ${data.keys.toList()}');
      print('📊 Status: ${data['status']}');

      // Cek apakah sudah digunakan
      if (data['status'] != 'pending') {
        print('❌ Token status is not pending: ${data['status']}');
        setState(() {
          _errorMessage = 'Token invitation sudah digunakan.';
          _isLoading = false;
        });
        return;
      }

      // Cek apakah expired (7 hari)
      final tokenExpiry = (data['tokenExpiry'] as Timestamp).toDate();
      final now = DateTime.now();
      print('⏰ Token expiry: $tokenExpiry');
      print('⏰ Current time: $now');
      print('⏰ Is expired: ${now.isAfter(tokenExpiry)}');
      
      if (now.isAfter(tokenExpiry)) {
        print('❌ Token expired');
        setState(() {
          _errorMessage = 'Token invitation sudah kadaluarsa. Hubungi admin untuk mendapatkan token baru.';
          _isLoading = false;
        });
        return;
      }

      // Invitation valid
      print('✅ Token validated successfully!');
      setState(() {
        _invitationData = data;
        _tokenValidated = true;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Error validating token: $e');
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

      print('📝 Starting registration for: $email');

      // Cek apakah email sudah terdaftar
      final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      
      if (signInMethods.isNotEmpty) {
        print('❌ Email already registered');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Email ini sudah terdaftar di sistem.\n\n'
                'Jika Anda lupa password, gunakan fitur "Lupa Password" di halaman login.\n\n'
                'Jika Anda merasa ini kesalahan, hubungi admin.'
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      print('✅ Email available, creating account...');

      // 1. Buat akun Firebase Auth dengan password BARU
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: newPassword,
      );

      final uid = credential.user!.uid;
      print('✅ Firebase Auth account created: $uid');

      // 2. Buat user document di Firestore
      print('📝 Creating user document in Firestore...');
      try {
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
        print('✅ User document created in Firestore');
      } catch (firestoreError) {
        print('❌ Firestore permission error: $firestoreError');
        // Rollback: Hapus user dari Auth jika gagal create document
        await credential.user?.delete();
        throw Exception(
          'Gagal membuat profil user di database.\n\n'
          'Kemungkinan penyebab:\n'
          '1. Firestore Security Rules tidak mengizinkan\n'
          '2. Masalah koneksi internet\n\n'
          'Silakan hubungi admin untuk bantuan.'
        );
      }

      // 3. Hapus invitation (sudah digunakan)
      await FirebaseFirestore.instance
          .collection('kurir_invitations')
          .doc(_tokenController.text.trim())
          .delete();
      
      print('✅ Invitation token deleted');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Registrasi berhasil! Silakan login dengan email dan password yang baru dibuat.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Sign out dan kembali ke login
        await FirebaseAuth.instance.signOut();
        print('✅ Signed out, navigating to login');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuth error: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMsg = ErrorHandler.getAuthErrorMessage(e);
        
        // Custom message untuk email-already-in-use
        if (e.code == 'email-already-in-use') {
          errorMsg = 'Email ini sudah terdaftar di sistem.\n\n'
              'Gunakan fitur "Lupa Password" di halaman login jika Anda lupa password.\n\n'
              'Atau hubungi admin jika Anda merasa ini kesalahan.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ General error: $e');
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
          : _tokenValidated && _invitationData != null
              ? _buildRegistrationForm(orange)
              : _buildTokenInputForm(orange),
    );
  }

  // Form input token
  Widget _buildTokenInputForm(Color orange) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vpn_key, size: 80, color: Color(0xFFFF7A00)),
            const SizedBox(height: 24),
            const Text(
              'Registrasi Kurir KatsuChip',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7A00),
              ),
            ),
            const SizedBox(height: 8),
            
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Token Invitation',
                hintText: 'Contoh: abc123xyz',
                prefixIcon: const Icon(Icons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                errorText: _errorMessage,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _validateInvitation,
                icon: const Icon(Icons.check_circle),
                label: const Text('Validasi Token', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Form registrasi (setelah token valid)
  Widget _buildRegistrationForm(Color orange) {
    if (_errorMessage != null) {
      return Center(
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
                onPressed: () {
                  setState(() {
                    _tokenValidated = false;
                    _errorMessage = null;
                    _invitationData = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.delivery_dining, size: 80, color: Color(0xFFFF7A00)),
            const SizedBox(height: 24),
            const Text(
              'Selamat Datang!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7A00),
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
                );
  }
}
