# 🚀 Quick Start Guide - Sistem Kurir KatsuChip

## 📋 Prasyarat

### 1. Setup Database (Firestore)
Pastikan struktur database Firestore sudah benar:

```javascript
// Collection: users
{
  "userId": {
    "name": "Nama User",
    "email": "email@example.com",
    "role": "courier",  // courier / admin / user
    "createdAt": Timestamp
  }
}

// Collection: orders
{
  "orderId": {
    "code": "ABC123",
    "userId": "customer-uid",
    "status": "delivering",
    "deliveryStatus": "waiting_pickup",
    "shippingAddress": {
      "name": "Nama Penerima",
      "phone": "08123456789",
      "address": "Jl. Contoh No. 123",
      "latitude": -6.200000,    // PENTING untuk Google Maps
      "longitude": 106.816666   // PENTING untuk Google Maps
    },
    "items": [...],
    "total": 50000,
    "createdAt": Timestamp
  }
}
```

### 2. Buat Akun Kurir
Di Firebase Console atau melalui kode:

```dart
// 1. Daftarkan user baru
// 2. Set role di Firestore:
FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .set({
    'name': 'John Doe',
    'email': 'kurir@example.com',
    'role': 'courier',  // PENTING!
    'createdAt': FieldValue.serverTimestamp(),
  });
```

## 🔄 Flow Lengkap

### STEP 1: Admin Terima Pesanan Baru
```
Admin → Orders → Pilih pesanan → 
Klik tombol sesuai status saat ini:
- Pending → "Konfirmasi Pesanan"
- Confirmed → "Proses Pesanan"  
- Processing → "Kirim Pesanan" ✅
```

**Hasil:**
- Status order berubah ke `delivering`
- **NOTIFIKASI OTOMATIS** dikirim ke semua kurir
- Log tercatat di `notification_logs`

### STEP 2: Kurir Login
```
Halaman Login → 
Scroll ke bawah →
Klik "Login sebagai Kurir" →
Masukkan email & password akun kurir →
Login
```

**Hasil:**
- Redirect ke Dashboard Kurir

### STEP 3: Kurir Lihat Pesanan
```
Dashboard Kurir →
Lihat statistik (sedang dikirim & terkirim hari ini) →
Filter pesanan (Semua / Menunggu Pickup / Dalam Pengiriman) →
Klik pesanan untuk detail
```

### STEP 4: Kurir Mulai Pengiriman
```
Detail Pesanan →
Lihat informasi lengkap →
Klik "Mulai Pengiriman"
```

**Hasil:**
- Status berubah ke `on_delivery`
- **NOTIFIKASI** ke Customer: "Pesanan sedang dalam perjalanan"
- **NOTIFIKASI** ke Admin: "Kurir [NAMA] memulai pengiriman"
- Log tercatat

### STEP 5: Navigasi dengan Google Maps
```
Detail Pesanan →
Klik "Buka di Google Maps" →
Google Maps terbuka dengan navigasi ke alamat
```

**Catatan:**
- Pastikan alamat memiliki `latitude` & `longitude`
- Jika tidak ada koordinat, akan muncul peringatan

### STEP 6: Hubungi Customer (Opsional)
```
Detail Pesanan →
Di bagian "Data Penerima" →
Klik icon telepon di samping nomor →
Aplikasi telepon terbuka
```

### STEP 7: Tandai Terkirim
```
Setelah sampai di lokasi →
Klik "Tandai Terkirim"
```

**Hasil:**
- Status order berubah ke `completed`
- Status delivery berubah ke `delivered`
- **NOTIFIKASI** ke Customer: "Pesanan telah sampai"
- **NOTIFIKASI** ke Admin: "Pesanan diterima customer"
- Log tercatat

## 🎯 Testing Checklist

### ✅ Test 1: Login Kurir
- [ ] Login dengan akun courier berhasil
- [ ] Login dengan akun non-courier ditolak
- [ ] Error message jelas

### ✅ Test 2: Dashboard
- [ ] Statistik muncul dengan benar
- [ ] List pesanan tampil
- [ ] Filter bekerja
- [ ] Pull to refresh bekerja

### ✅ Test 3: Detail Pesanan
- [ ] Semua informasi tampil lengkap
- [ ] Tombol muncul sesuai status
- [ ] Data penerima lengkap

### ✅ Test 4: Mulai Pengiriman
- [ ] Status berubah ke `on_delivery`
- [ ] Notifikasi terkirim ke customer ✅
- [ ] Notifikasi terkirim ke admin ✅
- [ ] Log tercatat di `notification_logs` ✅

### ✅ Test 5: Google Maps
- [ ] Tombol Google Maps muncul
- [ ] Google Maps terbuka dengan koordinat benar
- [ ] Jika tidak ada koordinat, muncul peringatan

### ✅ Test 6: Telepon Customer
- [ ] Icon telepon muncul
- [ ] Aplikasi telepon terbuka dengan nomor yang benar

### ✅ Test 7: Tandai Terkirim
- [ ] Status berubah ke `completed`
- [ ] Notifikasi terkirim ke customer ✅
- [ ] Notifikasi terkirim ke admin ✅
- [ ] Log tercatat ✅
- [ ] Halaman kembali ke dashboard

### ✅ Test 8: Notifikasi Admin ke Kurir
- [ ] Admin ubah status ke `delivering`
- [ ] Notifikasi muncul di semua akun kurir
- [ ] Log tercatat dengan benar

## 🔍 Troubleshooting

### Problem: Login kurir ditolak
**Solution:**
```dart
// Cek role di Firestore
FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .get()
  .then((doc) => print(doc.data()));

// Pastikan role = 'courier'
```

### Problem: Google Maps tidak terbuka
**Solution:**
1. Cek koordinat di database: `latitude` dan `longitude` harus ada
2. Pastikan permission sudah ditambahkan di `AndroidManifest.xml` dan `Info.plist`
3. Test dengan koordinat manual:
   ```dart
   latitude: -6.200000,
   longitude: 106.816666
   ```

### Problem: Notifikasi tidak terkirim
**Solution:**
1. Cek Firestore Rules - pastikan allow write untuk notifications
2. Cek console untuk error
3. Cek `notification_logs` collection untuk verifikasi

**Contoh Firestore Rules:**
```javascript
match /users/{userId}/notifications/{notifId} {
  allow read: if request.auth.uid == userId;
  allow write: if true; // Atau sesuaikan dengan security requirements
}

match /notification_logs/{logId} {
  allow read: if request.auth != null;
  allow write: if true;
}
```

### Problem: Statistik tidak akurat
**Solution:**
```dart
// Cek query di CourierService
// Pastikan filter berdasarkan courierId dan deliveryStatus
```

## 📱 Demo Credentials

Untuk testing, buat akun dengan kredensial berikut:

```
KURIR 1:
Email: kurir1@katsuchip.com
Password: kurir123
Role: courier

KURIR 2:
Email: kurir2@katsuchip.com  
Password: kurir123
Role: courier

ADMIN:
Email: admin@katsuchip.com
Password: admin123
Role: admin

CUSTOMER:
Email: customer@katsuchip.com
Password: customer123
Role: user
```

## 🎨 Tips UI/UX

1. **Warna Status:**
   - Orange = Waiting Pickup
   - Blue = On Delivery
   - Green = Delivered

2. **Pull to Refresh:**
   - Dashboard mendukung pull to refresh
   - Gunakan untuk update real-time

3. **Filter:**
   - Gunakan filter untuk fokus pada status tertentu
   - "Semua" untuk overview lengkap

4. **Notifikasi Badge:**
   - Jumlah notifikasi belum dibaca akan muncul
   - Klik notifikasi untuk mark as read

## 📞 Support

Jika ada pertanyaan atau issue:
1. Cek error di console: `flutter run` atau `flutter logs`
2. Periksa Firestore untuk data order
3. Cek `notification_logs` untuk tracking notifikasi

## 🎉 Selesai!

Sistem kurir sudah siap digunakan. Happy delivering! 🚚
