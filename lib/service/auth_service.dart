import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Getter yang dipakai di banyak tempat
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Validasi status user (isActive)
  Future<void> validateUserStatus(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    
    if (!doc.exists) {
      await _auth.signOut();
      throw Exception('Data user tidak ditemukan');
    }
    
    final data = doc.data();
    final isActive = data?['isActive'] as bool?;
    
    // Jika field isActive ada dan false, tolak login
    if (isActive == false) {
      await _auth.signOut();
      throw Exception('Akun Anda telah dinonaktifkan. Hubungi admin untuk informasi lebih lanjut.');
    }
  }

  // Email/Password dengan validasi status
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Validasi status user
    if (credential.user?.uid != null) {
      await validateUserStatus(credential.user!.uid);
    }
    
    return credential;
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    return cred;
  }

  // Google Sign-In dengan validasi status
  Future<UserCredential> signInWithGoogle() async {
    UserCredential credential;
    
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      credential = await _auth.signInWithPopup(provider);
    } else {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      if (gUser == null) {
        throw 'Login Google dibatalkan';
      }
      final gAuth = await gUser.authentication;
      final authCredential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      credential = await _auth.signInWithCredential(authCredential);
    }
    
    // Validasi status user
    if (credential.user?.uid != null) {
      await validateUserStatus(credential.user!.uid);
    }
    
    return credential;
  }

  Future<void> signOut() async {
    // Keluar dari Firebase dan Google (jika pernah login Google)
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore jika bukan login Google
    }
  }
}
