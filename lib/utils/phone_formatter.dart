import 'package:flutter/services.dart';

/// TextInputFormatter untuk format nomor telepon Indonesia
/// Format: +62 8xx-xxxx-xxxx
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Hanya ambil angka
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Jika kosong atau user sedang menghapus semua, return kosong
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    
    String formatted = '';
    int cursorPosition = 0;
    
    // Handle berbagai input format
    String processedDigits = digitsOnly;
    
    // Jika dimulai dengan 62, tambahkan +
    if (processedDigits.startsWith('62')) {
      processedDigits = processedDigits.substring(2);
    }
    // Jika dimulai dengan 0, remove 0
    else if (processedDigits.startsWith('0')) {
      processedDigits = processedDigits.substring(1);
    }
    
    // Jika tidak ada digit tersisa setelah proses, return kosong
    if (processedDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    
    // Format: +62 8xx-xxxx-xxxx
    formatted = '+62';
    
    if (processedDigits.isNotEmpty) {
      // Tambah spasi setelah +62
      formatted += ' ';
      
      // 3 digit pertama (8xx)
      if (processedDigits.length <= 3) {
        formatted += processedDigits;
      } else if (processedDigits.length <= 7) {
        // 3 digit + dash + sisanya (max 4)
        formatted += processedDigits.substring(0, 3);
        formatted += '-';
        formatted += processedDigits.substring(3);
      } else {
        // 3 digit + dash + 4 digit + dash + sisanya
        formatted += processedDigits.substring(0, 3);
        formatted += '-';
        formatted += processedDigits.substring(3, 7);
        formatted += '-';
        formatted += processedDigits.substring(7, processedDigits.length > 11 ? 11 : processedDigits.length);
      }
    }
    
    // Set cursor di akhir
    cursorPosition = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
  
  /// Extract nomor clean (hanya +62xxx tanpa format)
  static String cleanPhoneNumber(String formatted) {
    final digitsOnly = formatted.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';
    
    String cleaned = digitsOnly;
    if (cleaned.startsWith('62')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      return '+62${cleaned.substring(1)}';
    } else {
      return '+62$cleaned';
    }
  }
}
