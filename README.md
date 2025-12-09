# KatsuChip - Food Delivery App

Aplikasi delivery makanan berbasis Flutter dengan integrasi Firebase, Midtrans Payment Gateway, dan sistem kurir real-time.

## Features

### **Multi-Role System**
- **Customer**: Browse menu, order, track delivery
- **Admin**: Kelola menu, pesanan, dan verifikasi pembayaran
- **Kurir**: Terima pesanan, update status delivery, navigasi Google Maps

### **Payment Gateway**
- Integrasi Midtrans
- QRIS, GoPay, ShopeePay
- Transfer Bank (BCA, BNI, BRI, Mandiri, Bank Nagari)

###  **Delivery System**
- Real-time order tracking
- Google Maps navigation untuk kurir
- Push notifications (Admin ↔ Kurir ↔ Customer)
- Status tracking: waiting pickup → on delivery → delivered

###  **Authentication**
- Email & password
- Google Sign-In
- Role-based routing

---

## Quick Start

### Prerequisites
- Flutter SDK ^3.9.0
- Firebase account
- Midtrans account (Sandbox untuk testing)

### Installation

1. **Clone repository:**
```bash
git clone https://github.com/f4rma/katsuchip_mobile.git
cd katsuchip_mobile
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Setup Firebase:**
   - Buat project di [Firebase Console](https://console.firebase.google.com)
   - Download `google-services.json` → `android/app/`
   - Download `GoogleService-Info.plist` → `ios/Runner/`

4. **Setup Midtrans API Keys:**
   - Lihat panduan di `API_KEYS_SETUP.md`
   - Copy `lib/config/api_keys.dart.example` → `lib/config/api_keys.dart`
   - Isi dengan API keys dari Midtrans Dashboard

5. **Run app:**
```bash
flutter run
```

##  Tech Stack

- **Framework**: Flutter 3.9+
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Payment**: Midtrans Payment Gateway
- **State Management**: StatefulWidget
- **Maps**: Google Maps (via url_launcher)
- **Authentication**: Firebase Auth + Google Sign-In

---

##  Security

- API keys disimpan di file terpisah (`lib/config/api_keys.dart`) yang di-gitignore
- Firebase Security Rules untuk protect data
- Midtrans Server Key sebaiknya di backend (Cloud Functions) untuk production

---

##  Contributing

Pull requests are welcome! Untuk perubahan major, silakan buka issue dulu untuk diskusi.

---

##  License

This project is for educational purposes.

---

##  Developer

**Developed with ❤️ for KatsuChip**

Repository: https://github.com/f4rma/katsuchip_mobile

