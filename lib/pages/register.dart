import 'package:flutter/material.dart';
import 'package:katsuchip_app/service/auth_service.dart';
import 'package:katsuchip_app/utils/error_handler.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
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
              Image.asset(
                'assets/images/Splashscreen.jpg',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text(
                'Daftar ke Katsuchip',
                style: TextStyle(
                  color: Color(0xFFFF7A00),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _name,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Nama Lengkap',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _email,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Email atau Nomor Telepon',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () async {
                    setState(() { _loading = true; _error = null; });
                    try {
                      // Registrasi user baru, lalu set displayName
                      await AuthService().signUpWithEmail(
                        _email.text.trim(),
                        _password.text.trim(),
                        displayName: _name.text.trim(),
                      );

                      if (!mounted) return;
                      // Arahkan ke form pengisian data awal
                      Navigator.of(context).pushReplacementNamed('/setup');
                    } catch (e) {
                      setState(() { _error = ErrorHandler.getAuthErrorMessage(e); });
                    } finally {
                      if (mounted) setState(() { _loading = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_loading ? 'Mendaftarkan...' : 'Daftar'),
                ),
              ),

              const SizedBox(height: 12),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Sudah punya akun? Masuk'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/register-kurir');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7A00),
                ),
                child: const Text('Daftar Sebagai Kurir →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
