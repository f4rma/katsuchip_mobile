# 🔐 API Keys Setup

File ini menjelaskan cara setup API keys untuk development.

## 📋 Prerequisites

Sebelum menjalankan aplikasi, Anda perlu setup API keys untuk:
- **Midtrans Payment Gateway** (untuk pembayaran QRIS, Transfer Bank, dll)

---

## 🚀 Setup Instructions

### 1. Copy Template File

```bash
# Copy api_keys.dart.example menjadi api_keys.dart
copy lib\config\api_keys.dart.example lib\config\api_keys.dart
# atau di Mac/Linux:
# cp lib/config/api_keys.dart.example lib/config/api_keys.dart
```

### 2. Dapatkan Midtrans API Keys

1. **Daftar Midtrans:**
   - Buka https://dashboard.midtrans.com/register
   - Pilih "Sign up as Merchant"
   - Verifikasi email

2. **Get API Keys (Sandbox):**
   - Login ke https://dashboard.midtrans.com
   - Pilih **Sandbox** environment
   - Ke **Settings** → **Access Keys**
   - Copy:
     - **Client Key**: `SB-Mid-client-xxxxxxxxxxxxx`
     - **Server Key**: `SB-Mid-server-xxxxxxxxxxxxx`

3. **Isi ke `lib/config/api_keys.dart`:**
   ```dart
   class ApiKeys {
     static const String midtransClientKey = 'SB-Mid-client-xxxxxxxxxxxxx'; // Paste Client Key
     static const String midtransServerKey = 'SB-Mid-server-xxxxxxxxxxxxx'; // Paste Server Key
     static const bool midtransIsProduction = false; // false untuk testing
   }
   ```

### 3. Run Application

```bash
flutter pub get
flutter run
```

---

## ⚠️ Security Notes

- **JANGAN** commit file `lib/config/api_keys.dart` ke Git
- File ini sudah di-gitignore untuk keamanan
- Hanya commit file `api_keys.dart.example` (template kosong)
- Untuk production, gunakan Cloud Functions untuk generate Midtrans snap token (jangan hardcode Server Key di app)

---

## 📚 Documentation

- **Midtrans Integration:** Lihat `MIDTRANS_INTEGRATION.md`
- **Courier System:** Lihat `COURIER_SYSTEM.md`

---

## 🆘 Troubleshooting

### Error: `Cannot find 'ApiKeys'`
**Solusi:** Pastikan sudah copy `api_keys.dart.example` menjadi `api_keys.dart` dan isi dengan API keys yang benar.

### Payment gagal / "Invalid credentials"
**Solusi:** 
1. Check API keys sudah benar (copy dari Midtrans Dashboard)
2. Pastikan menggunakan Sandbox keys untuk testing
3. Check `midtransIsProduction = false` untuk Sandbox

---

**Developed with ❤️ for KatsuChip**
