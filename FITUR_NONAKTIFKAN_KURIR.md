# Fitur Nonaktifkan Kurir - Implementasi

## ✅ Yang Sudah Diimplementasikan

### 1. **Validasi Login (AuthService)**
```dart
// lib/service/auth_service.dart

Future<void> validateUserStatus(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  
  final isActive = doc.data()?['isActive'] as bool?;
  
  if (isActive == false) {
    await _auth.signOut();
    throw Exception('Akun Anda telah dinonaktifkan. Hubungi admin untuk informasi lebih lanjut.');
  }
}
```

**Efek:**
- ✅ Kurir yang dinonaktifkan **tidak bisa login**
- ✅ Auto logout jika isActive = false
- ✅ Pesan error yang jelas ditampilkan

---

### 2. **Toggle Status di Admin Dashboard**
```dart
// lib/pages/admin/admin_kurir.dart

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () => _toggleActive(context, doc, !isActive),
    icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
    label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
  ),
)
```

**Efek:**
- ✅ Admin bisa toggle status dengan 1 klik
- ✅ Update langsung ke Firestore: `isActive: true/false`
- ✅ Visual indicator: border hijau (aktif) / abu-abu (nonaktif)
- ✅ Badge status di card kurir

---

### 3. **Filter Notifikasi untuk Kurir Aktif**
```dart
// lib/service/notification_service.dart

final couriersSnapshot = await _db
    .collection('users')
    .where('role', isEqualTo: 'courier')
    .where('isActive', isEqualTo: true)  // ← Filter baru
    .get();
```

**Efek:**
- ✅ Hanya kurir aktif yang menerima notifikasi pesanan baru
- ✅ Kurir nonaktif tidak dapat assignment order
- ✅ Mencegah kurir nonaktif ambil pesanan

---

### 4. **Default Value saat Registrasi**
```dart
// lib/pages/admin/admin_kurir.dart - _registerKurir()

await FirebaseFirestore.instance.collection('users').doc(uid).set({
  'email': _emailController.text.trim(),
  'name': _nameController.text.trim(),
  'role': 'kurir',
  'phone': _phoneController.text.trim(),
  'isActive': true,  // ← Default aktif
  'createdAt': FieldValue.serverTimestamp(),
  'courierProfile': {
    'vehicleType': _vehicleController.text.trim(),
    'licensePlate': _plateController.text.trim(),
  }
});
```

**Efek:**
- ✅ Kurir baru otomatis aktif
- ✅ Bisa langsung menerima pesanan
- ✅ Admin bisa nonaktifkan kapan saja

---

## 🔄 Flow Lengkap

### **Skenario 1: Admin Nonaktifkan Kurir**

1. Admin buka halaman "Kelola Kurir"
2. Klik tombol **"Nonaktifkan"** pada card kurir
3. Firestore update: `users/{kurirUid}/isActive = false`
4. Status badge berubah ke "Nonaktif" (abu-abu)
5. Border card berubah ke abu-abu

**Dampak:**
- Kurir tidak bisa login lagi (auto logout jika sedang login)
- Tidak menerima notifikasi pesanan baru
- Tidak muncul di list kurir untuk assignment order

---

### **Skenario 2: Kurir Nonaktif Coba Login**

1. Kurir masukkan email & password
2. Firebase Auth berhasil (credential valid)
3. `AuthService.validateUserStatus()` dipanggil
4. Check `isActive` di Firestore
5. Jika `false` → Auto logout
6. Error ditampilkan: *"Akun Anda telah dinonaktifkan. Hubungi admin untuk informasi lebih lanjut."*

---

### **Skenario 3: Admin Aktifkan Kembali**

1. Admin klik tombol **"Aktifkan"** di card kurir
2. Firestore update: `users/{kurirUid}/isActive = true`
3. Status badge berubah ke "Aktif" (hijau)
4. Border card berubah ke hijau
5. Kurir bisa login kembali
6. Kurir mulai menerima notifikasi pesanan

---

## 📊 Struktur Data

### **Firestore: users/{kurirUid}**
```json
{
  "email": "kurir@example.com",
  "name": "Kurir 1",
  "role": "kurir",
  "phone": "08123456789",
  "isActive": true,  // ← Field penting
  "createdAt": "2025-11-24T10:00:00Z",
  "courierProfile": {
    "vehicleType": "motor",
    "licensePlate": "B 1234 XYZ"
  }
}
```

---

## 🔐 Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Admin bisa read semua user
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Admin bisa update isActive
      allow update: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isActive']);
      
      // Kurir bisa read data sendiri
      allow read: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## ✨ Keuntungan Fitur Ini

### **Dibanding Menghapus:**
1. ✅ **Data History Terjaga**
   - Delivery history tetap ada
   - Order yang pernah dikirim tetap tercatat
   - Bisa untuk audit dan analytics

2. ✅ **Reversible**
   - Bisa diaktifkan kembali kapan saja
   - Tidak perlu buat akun baru
   - Tidak perlu registrasi ulang

3. ✅ **Gratis**
   - Tidak perlu Cloud Functions
   - Tidak perlu upgrade Blaze Plan
   - Cukup update field Firestore

4. ✅ **Aman**
   - Tidak bisa login sampai diaktifkan
   - Tidak menerima notifikasi
   - Tidak bisa ambil pesanan baru

---

## 🧪 Testing Checklist

### **Test 1: Nonaktifkan Kurir**
- [ ] Admin klik "Nonaktifkan"
- [ ] Badge berubah jadi "Nonaktif"
- [ ] Border card berubah abu-abu
- [ ] Field `isActive` di Firestore = `false`

### **Test 2: Kurir Nonaktif Login**
- [ ] Kurir masukkan email/password yang benar
- [ ] Login ditolak dengan pesan error
- [ ] Auto logout jika sudah login
- [ ] Tidak bisa akses dashboard

### **Test 3: Kurir Nonaktif Tidak Dapat Notif**
- [ ] Admin kirim pesanan baru
- [ ] Notifikasi hanya ke kurir aktif
- [ ] Kurir nonaktif tidak dapat notif
- [ ] Cek collection `users/{kurirId}/notifications`

### **Test 4: Aktifkan Kembali**
- [ ] Admin klik "Aktifkan"
- [ ] Badge berubah jadi "Aktif"
- [ ] Border card berubah hijau
- [ ] Field `isActive` di Firestore = `true`
- [ ] Kurir bisa login lagi
- [ ] Kurir mulai dapat notif pesanan

---

## 🐛 Known Issues & Solutions

### **Issue 1: Kurir sudah login sebelum dinonaktifkan**
**Problem:** Kurir masih bisa akses app meski sudah dinonaktifkan

**Solution:** Tambahkan real-time listener di KurirDashboard:
```dart
@override
void initState() {
  super.initState();
  _checkActiveStatus();
}

void _checkActiveStatus() {
  final uid = AuthService().currentUser?.uid;
  if (uid == null) return;
  
  FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .listen((doc) {
    final isActive = doc.data()?['isActive'] as bool?;
    if (isActive == false) {
      AuthService().signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  });
}
```

### **Issue 2: Filter notifikasi belum jalan**
**Problem:** Kurir nonaktif masih dapat notif

**Check:**
1. Firestore query di `notification_service.dart` sudah include `where('isActive', isEqualTo: true)`?
2. Field `isActive` ada di semua dokumen kurir?
3. Composite index sudah dibuat di Firestore?

**Fix:** Buat composite index:
```
Collection: users
Fields: role (Ascending), isActive (Ascending)
Query scope: Collection
```

---

## 📈 Monitoring

### **Metrics yang Bisa Ditrack:**
- Jumlah kurir aktif vs nonaktif
- Alasan nonaktifkan (tambahkan field `deactivationReason`)
- Waktu nonaktif (tambahkan field `deactivatedAt`)
- Siapa yang nonaktifkan (tambahkan field `deactivatedBy`)

### **Enhanced Logging:**
```dart
await doc.reference.update({
  'isActive': newStatus,
  'lastStatusChange': FieldValue.serverTimestamp(),
  'statusChangedBy': FirebaseAuth.instance.currentUser?.uid,
  'statusChangeReason': reason, // Optional
});
```

---

## 🚀 Future Enhancements

1. **Auto-Nonaktifkan**
   - Nonaktifkan otomatis jika tidak login 30 hari
   - Nonaktifkan jika rating < 3.0

2. **Notifikasi ke Kurir**
   - Kirim email jika dinonaktifkan
   - Push notification tentang status change

3. **Reason Field**
   - Admin bisa kasih alasan nonaktifkan
   - Ditampilkan ke kurir saat login

4. **History Log**
   - Track semua status changes
   - Tampilkan di admin panel

5. **Batch Operations**
   - Nonaktifkan multiple kurir sekaligus
   - Export data kurir nonaktif

---

## 📞 Support

Untuk pertanyaan atau bug report:
- Check error di Firebase Console logs
- Review Security Rules di Firestore
- Test dengan Firestore Emulator dulu
