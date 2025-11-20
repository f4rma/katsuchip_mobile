# 💳 Integrasi Midtrans Payment Gateway - KatsuChip App

Panduan lengkap integrasi Midtrans untuk pembayaran QRIS, Transfer Bank (BCA, Mandiri, BNI, BRI, Bank Nagari), GoPay, ShopeePay, dan metode pembayaran lainnya.

---

## 📋 Prerequisites

1. **Akun Midtrans**
   - Daftar di https://dashboard.midtrans.com/register
   - Verifikasi akun email
   - Lengkapi data bisnis untuk production mode

2. **Flutter SDK** >= 3.9.0
3. **Firebase Project** sudah dikonfigurasi

---

## 🔧 Setup Midtrans Account

### 1. Login ke Midtrans Dashboard

https://dashboard.midtrans.com/

### 2. Get API Keys

**Untuk Testing (Sandbox Mode):**
1. Pilih **Sandbox** environment di dashboard
2. Ke **Settings** → **Access Keys**
3. Copy:
   - **Server Key**: `SB-Mid-server-xxxxxxxxxxxxx`
   - **Client Key**: `SB-Mid-client-xxxxxxxxxxxxx`

**Untuk Production:**
1. Lengkapi data bisnis & verifikasi
2. Pilih **Production** environment
3. Copy Server Key & Client Key production

### 3. Configure Payment Methods

Di **Settings** → **Payment Settings**, aktifkan:
- ✅ QRIS
- ✅ GoPay
- ✅ ShopeePay
- ✅ Bank Transfer (BCA, Mandiri, BNI, BRI, Permata)
- ✅ Other VA (untuk Bank Nagari, dll)

---

## 🚀 Setup di Aplikasi

### 1. Update API Keys

Edit file `lib/service/midtrans_service.dart`:

```dart
// Ganti dengan API keys Anda
static const String _clientKey = 'SB-Mid-client-xxxxxxxxxxxxx';
static const String _serverKey = 'SB-Mid-server-xxxxxxxxxxxxx';
static const bool _isProduction = false; // Set true untuk production
```

⚠️ **PENTING untuk Production:**
- **JANGAN** hardcode Server Key di aplikasi
- Gunakan backend/Cloud Function untuk generate snap token
- Server Key harus disimpan di server-side

### 2. Test dengan Sandbox

Gunakan nomor kartu test dari Midtrans:
- https://docs.midtrans.com/docs/testing-payment-on-sandbox

**Contoh Test Payment:**
- **QRIS**: Scan akan sukses otomatis di sandbox
- **GoPay**: Gunakan nomor `0812345678` untuk simulasi sukses
- **Virtual Account BCA**: `{server_key}01` untuk auto-approve

---

## 📱 Flow Pembayaran

```
1. User pilih menu → Add to cart
2. User klik Checkout
3. Pilih alamat pengiriman
4. User klik "Buat Pesanan"
   ↓
5. Order dibuat di Firestore (status: pending, paymentStatus: unpaid)
   ↓
6. App generate Snap Token dari Midtrans API
   ↓
7. Midtrans Payment UI muncul
   ↓
8. User pilih metode pembayaran (QRIS/Bank Transfer/E-wallet)
   ↓
9. User selesaikan pembayaran
   ↓
10. Callback: Update paymentStatus di Firestore
    - settlement/capture → "paid"
    - pending → "pending"
    - deny/expire/cancel → "failed"
   ↓
11. Admin lihat order dengan status payment terbaru
```

---

## 🔐 Security - Production Setup

### ⚠️ JANGAN expose Server Key di client!

**Rekomendasi Production:**

### Setup Cloud Function (Recommended)

1. **Install Firebase Functions:**
```bash
npm install -g firebase-tools
firebase init functions
```

2. **Create function `generateSnapToken`:**

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.generateSnapToken = functions.https.onCall(async (data, context) => {
  // Validate auth
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { orderId, grossAmount, customerName, customerEmail, customerPhone, items } = data;

  // Midtrans Server Key dari environment variable
  const serverKey = functions.config().midtrans.server_key;
  const isProduction = functions.config().midtrans.is_production === 'true';

  const url = isProduction
    ? 'https://app.midtrans.com/snap/v1/transactions'
    : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

  const auth = Buffer.from(serverKey + ':').toString('base64');

  try {
    const response = await axios.post(
      url,
      {
        transaction_details: {
          order_id: orderId,
          gross_amount: grossAmount,
        },
        customer_details: {
          first_name: customerName,
          email: customerEmail,
          phone: customerPhone,
        },
        item_details: items,
        enabled_payments: [
          'qris',
          'gopay',
          'shopeepay',
          'bca_va',
          'bni_va',
          'bri_va',
          'permata_va',
          'other_va',
        ],
      },
      {
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          Authorization: `Basic ${auth}`,
        },
      }
    );

    return { token: response.data.token };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

3. **Set environment variables:**
```bash
firebase functions:config:set midtrans.server_key="YOUR_SERVER_KEY"
firebase functions:config:set midtrans.is_production="false"
```

4. **Deploy:**
```bash
firebase deploy --only functions
```

5. **Update Flutter app** untuk call Cloud Function instead of direct API:

```dart
// Di midtrans_service.dart
Future<String?> getSnapToken(...) async {
  final callable = FirebaseFunctions.instance.httpsCallable('generateSnapToken');
  
  try {
    final result = await callable.call({
      'orderId': orderId,
      'grossAmount': grossAmount,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'items': items,
    });
    
    return result.data['token'] as String?;
  } catch (e) {
    print('Error calling Cloud Function: $e');
    return null;
  }
}
```

---

## 🧪 Testing

### Test Payment di Sandbox

1. **Run app:**
```bash
flutter run
```

2. **Checkout pesanan**
3. **Pilih metode pembayaran**
4. **Simulasi pembayaran:**
   - QRIS: Auto-approve di sandbox
   - GoPay: Gunakan nomor test `0812345678`
   - VA BCA: Gunakan nomor VA yang di-generate

5. **Verifikasi hasil:**
   - Check Firestore: `paymentStatus` harus berubah
   - Check admin dashboard: Order status terbaru
   - Check Midtrans Dashboard: Transaction log

### Test Cases

- ✅ Payment Success → `paymentStatus: "paid"`
- ✅ Payment Pending → `paymentStatus: "pending"`
- ✅ Payment Failed/Cancel → `paymentStatus: "failed"`
- ✅ User close payment UI sebelum bayar → Status tetap `unpaid`

---

## 📊 Monitoring Transactions

### Midtrans Dashboard

**Sandbox:** https://dashboard.sandbox.midtrans.com/transactions
**Production:** https://dashboard.midtrans.com/transactions

Fitur monitoring:
- Transaction list & details
- Payment status tracking
- Refund management
- Settlement reports

### Firebase Console

Check order documents di Firestore:
```
users/{userId}/orders/{orderId}
  - paymentStatus: "paid" | "pending" | "unpaid" | "failed"
  - midtransTransactionStatus: "settlement" | "pending" | ...
  - paymentUpdatedAt: timestamp
```

---

## 🐛 Troubleshooting

### Error: "Gagal membuat transaksi pembayaran"

**Solusi:**
1. Check API keys sudah benar
2. Check `_isProduction` sesuai environment
3. Check Midtrans server status
4. Check internet connection

### Payment UI tidak muncul

**Solusi:**
1. Check snap token berhasil di-generate
2. Check `midtrans_sdk` terinstall dengan benar
3. Check log console untuk error messages

### Payment status tidak update

**Solusi:**
1. Check internet saat callback
2. Check Firestore rules allow update
3. Manual check di Midtrans Dashboard
4. Test dengan simple payment method (QRIS)

### Server Key exposed warning

**Solusi:**
- Implement Cloud Function untuk production
- Jangan commit API keys ke Git
- Gunakan environment variables atau Firebase Remote Config

---

## 📚 Resources

- **Midtrans Docs:** https://docs.midtrans.com/
- **Snap API Reference:** https://snap-docs.midtrans.com/
- **Testing Guide:** https://docs.midtrans.com/docs/testing-payment-on-sandbox
- **Flutter SDK:** https://pub.dev/packages/midtrans_sdk

---

## 🎯 Next Steps

1. ✅ Test lengkap semua payment methods di sandbox
2. ✅ Setup Cloud Function untuk production (security)
3. ✅ Lengkapi data bisnis Midtrans untuk go-live
4. ✅ Update API keys ke production keys
5. ✅ Enable notification webhook untuk auto-update status
6. ✅ Test production payment dengan nominal kecil
7. ✅ Setup monitoring & alerts

---

## ⚠️ Production Checklist

Sebelum deploy ke production:

- [ ] Cloud Function untuk generate snap token sudah deploy
- [ ] Server Key tidak di-hardcode di aplikasi
- [ ] Data bisnis Midtrans sudah diverifikasi
- [ ] Payment methods production sudah diaktifkan
- [ ] Firestore security rules sudah proper
- [ ] Testing payment berhasil dengan nominal kecil
- [ ] Monitoring setup (Midtrans Dashboard + Firebase)
- [ ] Error handling & logging memadai
- [ ] User notification untuk payment success/failed

---

**Developed with ❤️ for KatsuChip**
