import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../utils/error_handler.dart';
import '../utils/phone_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // logo placeholder
              Image.asset(
                'assets/images/logo.jpg',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                'Masuk ke Katsuchip',
                style: TextStyle(
                  color: Color(0xFFFF7A00),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // email / phone
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Email',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // password
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Password',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sign In button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _loading ? null : () async {
                    setState(() { _loading = true; _error = null; });
                    try {
                      final cred = await AuthService().signInWithEmail(_email.text.trim(), _password.text.trim());
                      if (!mounted) return;
                      final uid = cred.user?.uid;
                      String route = '/main';
                      if (uid != null) {
                        try {
                          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                          final data = doc.data();
                          final role = (data?['role'] as String?) ?? 'user';
                          final mustChangePassword = (data?['mustChangePassword'] as bool?) ?? false;
                          
                          // Jika kurir wajib ganti password, redirect ke halaman ganti password
                          if (mustChangePassword && role == 'kurir') {
                            route = '/first-login-change-password';
                          } else if (role == 'admin') {
                            route = '/admin';
                          } else if (role == 'kurir') {
                            route = '/kurir';
                          }
                        } catch (_) {}
                      }
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed(route);
                    } catch (e) {
                      setState(() { _error = ErrorHandler.getAuthErrorMessage(e); });
                    } finally {
                      if (mounted) setState(() { _loading = false; });
                    }
                  },
                  child: Text(_loading ? 'Loading...' : 'Sign In'),
                ),
              ),

              const SizedBox(height: 12),

              // Ganti TextButton yang salah (sebelumnya membuka /register) menjadi label biasa
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'atau masuk dengan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),

              const SizedBox(height: 8),

              // Google button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Image.asset('assets/images/google_logo.png', width: 20, height: 20, fit: BoxFit.contain),
                  label: const Text('Google'),
                  onPressed: _loading ? null : () async {
                    setState(() { _loading = true; _error = null; });
                    try {
                      final cred = await AuthService().signInWithGoogle();
                      if (!mounted) return;
                      final uid = cred.user?.uid;
                      String route = '/main';
                      if (uid != null) {
                        try {
                          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                          final role = (doc.data()?['role'] as String?) ?? 'user';
                          if (role == 'admin') {
                            route = '/admin';
                          } else if (role == 'kurir') {
                            route = '/kurir';
                          }
                        } catch (_) {}
                      }
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed(route);
                    } catch (e) {
                      setState(() { _error = ErrorHandler.getAuthErrorMessage(e); });
                    } finally {
                      if (mounted) setState(() { _loading = false; });
                    }
                  },
                ),
              ),

              const SizedBox(height: 18),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              // const SizedBox(height: 18),
              // const Padding(
              //   padding: EdgeInsets.symmetric(horizontal: 8.0),
                // child: Text(
                //   'Dengan masuk di sini, kamu menyetujui Syarat & Ketentuan serta Kebijakan Privasi Katsuchip',
                //   textAlign: TextAlign.center,
                //   style: TextStyle(fontSize: 11, color: Colors.black54),
                // ),
              // ),

              const SizedBox(height: 12),
              // Link "Belum punya akun? Daftar sekarang!"
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    text: 'Belum punya akun? ',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Daftar sekarang!',
                        style: TextStyle(
                          color: Color(0xFF1E88E5), // link biru sesuai desain
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),                          

            ],
          ),
        ),
      ),
    );
  }
}
