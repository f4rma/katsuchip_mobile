# Sistem Kurir KatsuChip

## 📦 Deskripsi
Sistem kurir yang terintegrasi lengkap untuk mengelola pengiriman pesanan dengan notifikasi real-time antar role (Admin, Kurir, dan Pembeli).

## 🚀 Fitur Utama

### 1. **Login Khusus Kurir**
- Halaman login terpisah dengan validasi role
- Hanya akun dengan role `courier` yang bisa akses
- Terintegrasi dengan Firebase Authentication
- Link ke login kurir tersedia di halaman login utama

### 2. **Dashboard Kurir**
- **Statistik Real-time:**
  - Jumlah pesanan sedang dikirim
  - Jumlah pesanan terkirim hari ini
  - Total pengiriman sepanjang waktu

- **Filter Pesanan:**
  - Semua pesanan
  - Menunggu Pickup (waiting_pickup)
  - Sedang Dikirim (on_delivery)

- **Informasi Pesanan:**
  - Kode pesanan
  - Nama penerima
  - Alamat pengiriman
  - Nomor telepon
  - Total belanja
  - Status pengiriman

### 3. **Detail Pesanan**
- Informasi lengkap pesanan
- Data penerima (nama, telepon, alamat)
- Daftar item yang dipesan
- Tombol aksi sesuai status:
  - **Waiting Pickup**: Tombol "Mulai Pengiriman"
  - **On Delivery**: Tombol "Tandai Terkirim"
  - **Delivered**: Status terkirim

### 4. **Integrasi Google Maps**
- Tombol navigasi langsung ke Google Maps
- Mendukung koordinat latitude & longitude
- Membuka aplikasi Google Maps untuk navigasi

### 5. **Komunikasi dengan Customer**
- Tombol telepon langsung ke customer
- Terintegrasi dengan aplikasi telepon device

## 🔔 Sistem Notifikasi

### Admin → Kurir
**Trigger**: Ketika admin mengubah status pesanan ke `delivering`
- Notifikasi dikirim ke **SEMUA kurir**
- Pesan: "Pesanan baru tersedia untuk dikirim: #[CODE]"
- Logged di collection `notification_logs`

### Kurir → Pembeli
**Trigger 1**: Kurir mulai pengiriman
- Pesan: "Pesanan Anda sedang dalam perjalanan! Kurir: [NAMA]"

**Trigger 2**: Kurir tandai sebagai terkirim
- Pesan: "Pesanan Anda telah sampai! Terima kasih telah berbelanja."

### Kurir → Admin
**Trigger 1**: Kurir mulai pengiriman
- Pesan: "Kurir [NAMA] memulai pengiriman pesanan #[CODE]"
- Status: `started`

**Trigger 2**: Pesanan diterima customer
- Pesan: "Pesanan #[CODE] telah diterima customer"
- Status: `completed`

## 📁 Struktur File

```
lib/
├── models/
│   └── courier_models.dart          # Model CourierOrder, CourierStats, NotificationLog
│
├── service/
│   ├── notification_service.dart    # Service untuk sistem notifikasi
│   └── courier_service.dart         # Service untuk operasi kurir
│
└── pages/
    └── courier/
        ├── courier_login.dart       # Halaman login kurir
        ├── courier_dashboard.dart   # Dashboard utama kurir
        └── courier_order_detail.dart # Detail pesanan dengan aksi
```

## 🗄️ Struktur Database (Firestore)

### Collection: `orders`
```javascript
{
  "orderId": "auto-generated-id",
  "code": "ABC123",
  "userId": "customer-uid",
  "status": "delivering",           // pending, confirmed, processing, delivering, completed
  "deliveryStatus": "waiting_pickup", // waiting_pickup, on_delivery, delivered
  "courierId": "courier-uid",       // ID kurir yang handle
  "deliveryStartedAt": Timestamp,   // Waktu mulai kirim
  "deliveredAt": Timestamp,         // Waktu terkirim
  "shippingAddress": {
    "name": "Nama Penerima",
    "phone": "08123456789",
    "address": "Jl. Contoh No. 123",
    "latitude": -6.200000,          // Optional, untuk Google Maps
    "longitude": 106.816666         // Optional, untuk Google Maps
  },
  "items": [...],
  "total": 50000,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Collection: `users/{userId}/notifications`
```javascript
{
  "type": "delivery_update",        // order_available, delivery_update, delivery_status
  "orderId": "order-id",
  "orderCode": "ABC123",
  "message": "Pesanan Anda sedang dalam perjalanan!",
  "from": "courier",                // admin, courier, system
  "fromId": "courier-uid",
  "courierName": "John Doe",        // Opsional
  "read": false,
  "createdAt": Timestamp
}
```

### Collection: `notification_logs`
```javascript
{
  "type": "courier_to_customer",    // admin_to_courier, courier_to_customer, courier_to_admin
  "from": "courier:uid",
  "to": "customer:uid",
  "orderId": "order-id",
  "message": "Pesanan Anda sedang dalam perjalanan!",
  "data": {
    "orderCode": "ABC123",
    "courierName": "John Doe"
  },
  "createdAt": Timestamp
}
```

## 🔐 Role Management

### Setup Role Kurir di Firestore:
```javascript
// Collection: users/{userId}
{
  "name": "Nama Kurir",
  "email": "kurir@example.com",
  "role": "courier",              // Wajib untuk akses sistem kurir
  "createdAt": Timestamp
}
```

## 🛣️ Routing

```dart
'/courier-login' → CourierLoginPage     // Login khusus kurir
'/courier'       → CourierDashboardPage // Dashboard kurir
```

## 📱 Cara Penggunaan

### Untuk Admin:
1. Login sebagai admin
2. Buka menu pesanan
3. Ubah status pesanan ke "Kirim Pesanan" (delivering)
4. Notifikasi otomatis dikirim ke semua kurir

### Untuk Kurir:
1. Klik "Login sebagai Kurir" di halaman login
2. Login dengan akun yang memiliki role `courier`
3. Dashboard menampilkan pesanan yang tersedia
4. Filter pesanan berdasarkan status
5. Klik pesanan untuk melihat detail
6. Klik "Mulai Pengiriman" untuk memulai
7. Gunakan "Buka di Google Maps" untuk navigasi
8. Setelah sampai, klik "Tandai Terkirim"

### Untuk Pembeli:
1. Menerima notifikasi saat kurir mulai pengiriman
2. Menerima notifikasi saat pesanan terkirim
3. Dapat melihat notifikasi di menu profil/notifikasi

## 🔧 Dependencies Baru

```yaml
url_launcher: ^6.3.1  # Untuk integrasi Google Maps & telepon
```

## ⚙️ Konfigurasi Tambahan

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<!-- Tambahkan permission untuk URL launcher -->
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
  <intent>
    <action android:name="android.intent.action.DIAL" />
    <data android:scheme="tel" />
  </intent>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="geo" />
  </intent>
</queries>
```

### iOS (ios/Runner/Info.plist)
```xml
<!-- Tambahkan untuk URL schemes -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>https</string>
  <string>http</string>
  <string>tel</string>
  <string>comgooglemaps</string>
</array>
```

## 🎨 Design System

### Warna:
- Primary Orange: `#FF7A00`
- Background: `#FFF7ED`
- Success Green: `Colors.green`
- Info Blue: `Colors.blue`

### Status Colors:
- Waiting Pickup: Orange
- On Delivery: Blue
- Delivered: Green

## 📊 Flow Diagram

```
Admin Update Status "delivering"
    ↓
Notifikasi ke Semua Kurir + Log
    ↓
Kurir Lihat di Dashboard
    ↓
Kurir Klik "Mulai Pengiriman"
    ↓
Status → "on_delivery"
Notifikasi → Customer & Admin + Log
    ↓
Kurir Navigasi dengan Google Maps
    ↓
Kurir Klik "Tandai Terkirim"
    ↓
Status → "completed"
Notifikasi → Customer & Admin + Log
```

## 🧪 Testing

### Test Scenario:
1. ✅ Login sebagai kurir dengan role yang tepat
2. ✅ Login ditolak jika bukan role courier
3. ✅ Dashboard menampilkan statistik yang benar
4. ✅ Filter pesanan berfungsi
5. ✅ Notifikasi terkirim saat admin update ke delivering
6. ✅ Notifikasi terkirim saat kurir mulai pengiriman
7. ✅ Notifikasi terkirim saat pesanan terkirim
8. ✅ Google Maps terbuka dengan koordinat yang benar
9. ✅ Telepon customer berfungsi
10. ✅ Semua logs tercatat di notification_logs

## 🚨 Catatan Penting

1. **Koordinat GPS**: Untuk fitur Google Maps berfungsi optimal, pastikan data alamat customer memiliki `latitude` dan `longitude`
2. **Permission**: Pastikan app memiliki permission untuk membuka URL eksternal
3. **Role Management**: Hanya akun dengan role `courier` yang bisa akses sistem kurir
4. **Notifikasi Real-time**: Menggunakan Firestore Streams untuk update real-time
5. **Logging**: Semua notifikasi dicatat di `notification_logs` untuk audit trail

## 📝 TODO / Future Improvements

- [ ] Push notification (FCM) untuk notifikasi real-time
- [ ] History pengiriman kurir
- [ ] Rating & review untuk kurir
- [ ] Live tracking location
- [ ] Optimasi rute pengiriman
- [ ] Proof of delivery (foto/signature)
- [ ] Earning tracking untuk kurir

## 👥 Contributors

Developed for KatsuChip App - Courier Management System
