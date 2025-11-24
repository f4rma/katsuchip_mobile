import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ErrorHandler {
  /// Konversi Firestore exception ke pesan user-friendly
  static String getFirestoreErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Anda tidak memiliki akses';
        case 'unavailable':
          return 'Layanan tidak tersedia. Coba lagi nanti';
        case 'not-found':
          return 'Data tidak ditemukan';
        case 'already-exists':
          return 'Data sudah ada';
        case 'resource-exhausted':
          return 'Kuota terlampaui. Coba lagi nanti';
        case 'failed-precondition':
          return 'Operasi gagal. Periksa koneksi Anda';
        case 'aborted':
          return 'Operasi dibatalkan. Silakan coba lagi';
        case 'out-of-range':
          return 'Data di luar jangkauan yang valid';
        case 'unimplemented':
          return 'Fitur tidak tersedia';
        case 'internal':
          return 'Terjadi kesalahan internal';
        case 'data-loss':
          return 'Data hilang atau rusak';
        case 'unauthenticated':
          return 'Anda belum login';
        case 'deadline-exceeded':
          return 'Koneksi timeout. Periksa internet Anda';
        default:
          return error.message ?? 'Terjadi kesalahan pada database';
      }
    }
    
    if (error is SocketException) {
      return 'Koneksi internet terputus';
    }
    
    return error.toString();
  }

  /// Konversi Firebase Auth exception ke pesan user-friendly
  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        // Login errors
        case 'user-not-found':
          return 'Email tidak terdaftar';
        case 'wrong-password':
          return 'Password salah';
        case 'invalid-email':
          return 'Format email tidak valid';
        case 'user-disabled':
          return 'Akun Anda telah dinonaktifkan';
        case 'invalid-credential':
          return 'Email atau password salah';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan login. Coba lagi nanti';
        
        // Register errors
        case 'email-already-in-use':
          return 'Email sudah terdaftar';
        case 'weak-password':
          return 'Password terlalu lemah (minimal 6 karakter)';
        case 'operation-not-allowed':
          return 'Metode login ini tidak diizinkan';
        
        // Network errors
        case 'network-request-failed':
          return 'Koneksi internet terputus';
        
        // Other auth errors
        case 'account-exists-with-different-credential':
          return 'Email sudah terdaftar dengan metode login berbeda';
        case 'invalid-verification-code':
          return 'Kode verifikasi tidak valid';
        case 'invalid-verification-id':
          return 'ID verifikasi tidak valid';
        case 'session-expired':
          return 'Sesi telah berakhir. Silakan login ulang';
        
        default:
          return error.message ?? 'Terjadi kesalahan autentikasi';
      }
    }
    
    if (error is FirebaseException) {
      return getFirestoreErrorMessage(error);
    }
    
    if (error is SocketException) {
      return 'Koneksi internet terputus';
    }
    
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    
    return error.toString();
  }

  /// Validasi input dengan pesan error yang jelas
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format email tidak valid';
    }
    
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    
    if (value.length < 3) {
      return 'Nama minimal 3 karakter';
    }
    
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }
    
    // Format Indonesia: 08xxx atau +62xxx
    final phoneRegex = RegExp(r'^(?:\+62|0)\d{8,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Format nomor telepon tidak valid (contoh: 08123456789)';
    }
    
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  /// Show error dialog dengan opsi retry
  static Future<bool> showErrorDialog({
    required dynamic context,
    required String title,
    required String message,
    bool showRetry = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          if (showRetry)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(showRetry ? 'Coba Lagi' : 'OK'),
          ),
        ],
      ),
    ) ?? false;
  }
}
