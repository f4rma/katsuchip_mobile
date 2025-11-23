# Kelola Kurir - Panduan Admin

## 📋 Fitur yang Tersedia

### ✅ Yang Bisa Dilakukan di App:

1. **Lihat Daftar Kurir**
   - Semua kurir yang terdaftar ditampilkan real-time
   - Informasi lengkap: nama, email, HP, kendaraan, plat nomor
   - Status aktif/nonaktif dengan badge berwarna

2. **Aktifkan/Nonaktifkan Kurir**
   - Toggle status dengan satu klik
   - Border hijau untuk aktif, abu-abu untuk nonaktif
   - Update langsung ke Firestore

3. **Tambah Kurir Baru**
   - Form lengkap dengan 6 field
   - Otomatis membuat akun Firebase Auth
   - Menyimpan data ke Firestore dengan role="kurir"

### ❌ Yang TIDAK Bisa Dilakukan (Perlu Firebase Console):

**Menghapus Kurir**
- Menghapus user dari Firebase Authentication memerlukan **Admin SDK**
- Admin SDK hanya bisa dijalankan di server (Cloud Functions dengan Blaze Plan)
- Untuk development/project gratis, hapus manual via Firebase Console

---

## 🗑️ Cara Menghapus Kurir Manual

### Via Firebase Console:

1. **Hapus dari Authentication:**
   - Buka: https://console.firebase.google.com/project/katsuchip-65298/authentication/users
   - Cari kurir berdasarkan email
   - Klik menu ⋮ → **Delete account**
   - Konfirmasi penghapusan

2. **Hapus dari Firestore:**
   - Buka: https://console.firebase.google.com/project/katsuchip-65298/firestore/databases/-default-/data/~2Fusers
   - Cari dokumen dengan UID kurir yang sama
   - Klik menu ⋮ → **Delete document**
   - Konfirmasi penghapusan

⚠️ **Penting**: Hapus dari kedua tempat (Auth + Firestore) agar konsisten!

---

## 🔄 Alternatif: Nonaktifkan Saja

Daripada menghapus, lebih baik **nonaktifkan kurir**:

### Keuntungan:
- ✅ Data history tetap tersimpan
- ✅ Bisa diaktifkan kembali kapan saja
- ✅ Tidak perlu akses Firebase Console
- ✅ Lebih aman untuk audit trail

### Implementasi:
Sudah tersedia di app! Klik tombol **"Nonaktifkan"** pada card kurir.

Kurir yang nonaktif:
- Tidak bisa login (cek di AuthService)
- Tidak muncul di list kurir aktif (filter `where('isActive', isEqualTo: true)`)
- Badge berubah warna abu-abu

---

## 🚀 Upgrade ke Production (Optional)

Jika nantinya perlu fitur hapus di app, upgrade ke **Firebase Blaze Plan**:

### Setup Cloud Functions:

1. **Upgrade Plan:**
   - Buka: https://console.firebase.google.com/project/katsuchip-65298/usage/details
   - Klik "Upgrade to Blaze"
   - Free tier: 2M invocations/month (cukup untuk app kecil)

2. **Deploy Function:**
   ```powershell
   npm install -g firebase-tools
   firebase init functions
   # Pilih Python
   # Deploy
   firebase deploy --only functions
   ```

3. **Add Delete Button:**
   Uncomment kode delete di `admin_kurir.dart` dan tambahkan Cloud Function.

### Estimasi Cost:
- **Development**: $0/bulan (dalam free tier)
- **Small Production** (100 delete/month): ~$0.02/bulan
- **Medium Production** (1000 delete/month): ~$0.20/bulan

---

## 📊 Data Structure

```
users/{kurirUid}/
  ├── email: string
  ├── name: string
  ├── role: "kurir"
  ├── phone: string
  ├── isActive: boolean  ← Toggle status
  ├── createdAt: timestamp
  └── courierProfile/
      ├── vehicleType: string
      └── licensePlate: string
```

### Security Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Admin bisa baca semua user
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      
      // Admin bisa update isActive
      allow update: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isActive']);
      
      // Admin bisa create user baru (via register kurir)
      allow create: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## 🔐 Best Practices

1. **Jangan Hapus, Nonaktifkan**
   - Lebih aman untuk audit
   - Data history terjaga
   - Bisa rollback kapan saja

2. **Backup Regular**
   - Export Firestore data berkala
   - Simpan di Google Cloud Storage
   - Gunakan Firebase Extensions "Firestore Backup"

3. **Monitor Activity**
   - Check logs di Firebase Console
   - Track siapa yang nonaktifkan kurir
   - Tambahkan audit log jika perlu

4. **Role-Based Access**
   - Hanya admin yang bisa kelola kurir
   - Check role di Security Rules
   - Validasi di app layer juga

---

## 🐛 Troubleshooting

### Kurir Tidak Muncul di List
- Pastikan field `role` = "kurir"
- Check Firestore Console
- Lihat query: `where('role', isEqualTo: 'kurir')`

### Toggle Status Tidak Work
- Check internet connection
- Lihat Firebase Console logs
- Pastikan Security Rules allow update

### Kurir Masih Bisa Login Setelah Nonaktif
- Tambahkan check di `AuthService`:
  ```dart
  final userData = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  if (userData.data()?['isActive'] == false) {
    await FirebaseAuth.instance.signOut();
    throw Exception('Akun Anda telah dinonaktifkan');
  }
  ```

---

## 📞 Support

Untuk pertanyaan lebih lanjut:
- Firebase Docs: https://firebase.google.com/docs
- Stack Overflow: Tag `firebase` + `flutter`
- Firebase Support: https://firebase.google.com/support
