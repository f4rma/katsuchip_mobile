import 'dart:async';
import '../service/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Splashscreen extends StatefulWidget{
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> with SingleTickerProviderStateMixin{
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState(){
    super .initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // (opsional) preload gambar supaya pasti tampil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/Splashscreen.jpg'), context);
    });

    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      // cek auth state cepat
      final sub = AuthService().authStateChanges.listen((user) async {
        if (!mounted) return;
        if (user == null) {
          Navigator.of(context).pushReplacementNamed('/login');
        } else {
          // cek role di users/{uid}
          try {
            final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            final role = (doc.data()?['role'] as String?) ?? 'user';
            if (!mounted) return;
            String route = '/main';
            if (role == 'admin') {
              route = '/admin';
            } else if (role == 'kurir') {
              route = '/kurir';
            }
            Navigator.of(context).pushReplacementNamed(route);
          } catch (_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/main');
          }
        }
      });
      // batasi listener satu kali
      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();
    });
  }

  @override
  void dispose(){
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED), // Warna krem sesuai logo
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              Image.asset(
                'assets/images/Splashscreen.jpg',
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A00)),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }
}
