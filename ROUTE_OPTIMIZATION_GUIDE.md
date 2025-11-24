# 🚀 Route Optimization System - KatsuChip

## Overview
Sistem optimasi rute pengiriman untuk kurir KatsuChip menggunakan **Nearest Neighbor Algorithm** dan **Haversine Distance Calculation**.

## ✅ Yang Sudah Diimplementasi

### 1. Dependencies
```yaml
# pubspec.yaml
dependencies:
  google_maps_flutter: ^2.10.0  # Display maps
  geolocator: ^13.0.2           # Get device location
  geocoding: ^3.0.0             # Geocoding support
  http: ^1.2.0                  # API calls
```

### 2. Services

#### GeocodingService (`lib/service/geocoding_service.dart`)
- **Free geocoding** menggunakan Nominatim (OpenStreetMap)
- Convert alamat text → koordinat (lat/lng)
- Rate limit: 1 request/second (built-in delay)
- No API key required ✅

```dart
// Usage example:
final coords = await GeocodingService.getCoordinates('Jl. Sudirman No. 1, Jakarta');
if (coords != null) {
  print('Lat: ${coords['latitude']}, Lng: ${coords['longitude']}');
}
```

#### DistanceCalculator (`lib/service/distance_calculator.dart`)
- Haversine formula untuk akurasi tinggi
- Hitung jarak antar koordinat dalam km/meter
- Check apakah 2 lokasi berdekatan (radius)
- Hitung total distance untuk multi-point route

```dart
// Usage example:
final distance = DistanceCalculator.calculateDistance(
  -6.2088, 106.8456, // Jakarta
  -6.9175, 107.6191, // Bandung
);
print('Jarak: ${DistanceCalculator.formatDistance(distance)}');
```

#### RouteOptimizerService (`lib/service/route_optimizer_service.dart`)
- **Nearest Neighbor Algorithm** untuk optimasi urutan delivery
- Grouping orders berdasarkan kedekatan (radius 2km default)
- Auto-assign batch ke kurir dengan sequence number

**Algoritma:**
1. Ambil semua pending orders dengan koordinat
2. Group orders yang berdekatan (radius 2km)
3. Optimize urutan di tiap batch (nearest neighbor dari toko)
4. Assign batch ke kurir dengan deliverySequence

```dart
// Usage example:
final batches = await RouteOptimizerService.createOptimalBatches();
// Returns: {'BATCH_123': [order1, order2, order3], ...}

// Assign to courier:
await RouteOptimizerService.assignBatchToKurir(
  kurirId: 'kurir-uid',
  batchId: 'BATCH_123',
  orders: batchOrders,
);
```

### 3. Order Model Update
Setiap order sekarang otomatis di-geocode saat checkout:

```dart
// cart_repository.dart - placeOrder()
{
  'latitude': -6.2088,     // Auto-geocoded
  'longitude': 106.8456,   // Auto-geocoded
  'address': 'Jl. ...',    // Full address
  'batchId': 'BATCH_123',  // Assigned by admin
  'deliverySequence': 1,   // Order in route (1, 2, 3, ...)
  'kurirId': 'kurir-uid',  // Assigned courier
  // ... other fields
}
```

## 🔧 Setup Google Maps API Key

### Step 1: Get API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create/select project
3. Enable APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - (Optional) Directions API untuk polyline routes
4. Create API Key

### Step 2: Add to Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest ...>
    <application ...>
        <!-- Replace YOUR_GOOGLE_MAPS_API_KEY_HERE -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="AIzaSy...YOUR_KEY_HERE"/>
        ...
    </application>
</manifest>
```

### Step 3: Add to iOS
Edit `ios/Runner/AppDelegate.swift`:
```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 4: Set Minimum iOS Version
Edit `ios/Podfile`:
```ruby
platform :ios, '14.0'
```

## 📊 Cost Estimation

| Service | Cost | Usage |
|---------|------|-------|
| **Nominatim Geocoding** | FREE ✅ | Unlimited (rate limited) |
| **Haversine Calculation** | FREE ✅ | Client-side math |
| **Google Maps Display** | FREE | Up to 28,000 map loads/month |
| **Directions API** | $5/1000 | Optional polyline routes |

**Estimated Monthly Cost**: Rp 0 - Rp 50,000 (tergantung volume)

## 🎯 How It Works

### For Customer:
1. Checkout → Alamat otomatis di-geocode
2. Order masuk dengan koordinat lat/lng
3. Tracking: Lihat status pengiriman (future feature)

### For Admin:
1. Lihat pending orders
2. Klik "Optimasi & Assign Rute"
3. Sistem grouping orders yang searah/berdekatan
4. Preview batch dengan urutan optimal
5. Pilih kurir → Assign batch

### For Kurir:
1. Terima notifikasi: "3 pesanan baru (Batch #123)"
2. Buka dashboard → Lihat list orders dengan sequence
3. Klik "Lihat Rute di Maps"
4. Maps menampilkan:
   - Marker toko (start point)
   - Marker #1, #2, #3 (delivery points)
   - Optional: Route polyline
5. Tap marker → Buka Google Maps/Waze untuk navigation
6. Update status per-pesanan saat sampai

## 🔄 Algorithm Details

### Nearest Neighbor (Greedy)
```
1. Start from store location
2. Find nearest unvisited order
3. Move to that location
4. Repeat until all orders visited
5. Return sequence: [order1, order2, order3]
```

**Complexity**: O(n²)  
**Optimal untuk**: < 20 orders per batch  
**Hasil**: 70-80% optimal (good enough untuk KatsuChip scale)

### Grouping Logic
```
For each order O1:
  Create new batch B
  Add O1 to B
  For each other order O2:
    If distance(O1, O2) <= 2km:
      Add O2 to B
```

## 🚧 TODO: Implementasi Selanjutnya

### 1. Admin Batch Assignment UI
File: `lib/pages/admin/admin_batch_assignment.dart`

```dart
// Features:
- List pending orders dengan lokasi
- Preview orders on map
- Button "Optimasi Rute"
- Show batches dengan sequence & total distance
- Dropdown pilih kurir
- Button "Assign ke Kurir"
```

### 2. Kurir Map View
File: `lib/pages/kurir/kurir_map_view.dart`

```dart
// Features:
- GoogleMap widget
- Store marker (start point)
- Numbered markers untuk setiap delivery (1, 2, 3)
- Optional: Polyline route
- Info window dengan detail order
- Button "Buka di Google Maps" per marker
```

### 3. Kurir Dashboard Enhancement
File: `lib/pages/kurir/kurir_dashboard.dart`

```dart
// Add:
- Badge: "3 Pesanan Aktif (Batch #123)"
- List orders dengan deliverySequence
- Button "Lihat Rute di Maps"
- Checkbox "Selesai" per order
```

### 4. Real-time Tracking (Future)
```dart
// Optional advanced feature:
- Kurir broadcast lokasi setiap 30 detik
- Pembeli lihat live location kurir
- ETA calculation
- Push notification: "Kurir 2 menit lagi"
```

## 📝 Firestore Rules Update

Rules sudah support batch delivery:

```javascript
// orders collection
match /{path=**}/orders/{orderId} {
  // Admin bisa query semua orders (untuk batching)
  allow read: if isAdmin();
  
  // Kurir bisa read orders yang di-assign ke dia
  allow read: if isKurir() && 
                 resource.data.kurirId == request.auth.uid;
  
  // Kurir bisa update deliverySequence status
  allow update: if isKurir() && 
                   resource.data.kurirId == request.auth.uid;
}
```

## 🧪 Testing

### 1. Test Geocoding
```dart
final coords = await GeocodingService.getCoordinates('Jl. MH Thamrin, Jakarta');
print(coords); // Should return lat/lng
```

### 2. Test Distance
```dart
final distance = DistanceCalculator.calculateDistance(
  -6.2088, 106.8456,
  -6.2100, 106.8470,
);
print('${distance.toStringAsFixed(2)} km'); // Should be ~1-2 km
```

### 3. Test Batching
```dart
// Create 3 test orders dengan lokasi berdekatan
// Run optimizer
final batches = await RouteOptimizerService.createOptimalBatches();
print('Batches: ${batches.length}'); // Should group nearby orders
```

## 📱 User Flow Example

**Scenario**: 3 orders datang bersamaan

1. **Order A**: Jl. Sudirman No. 10 (-6.2088, 106.8456)
2. **Order B**: Jl. Sudirman No. 50 (-6.2095, 106.8460) → **200m dari A**
3. **Order C**: Jl. Gatot Subroto (-6.2200, 106.8300) → **2.5km dari A**

**Optimizer Result**:
- **Batch 1**: Order A, B (berdekatan, sequence: A→B)
- **Batch 2**: Order C (jauh, separate batch)

**Kurir Workflow**:
- Kurir X: Batch 1 (2 orders)
- Kurir Y: Batch 2 (1 order)

**Benefit**: Kurir X hemat waktu karena A & B searah, tidak perlu bolak-balik

## 🎨 UI Mockup

### Admin: Batch Assignment
```
┌─────────────────────────────────┐
│ 🗺️  Optimasi Rute Pengiriman   │
├─────────────────────────────────┤
│ 📍 5 Pesanan Pending            │
│                                  │
│ Batch #1 (3 orders, 4.2 km)    │
│  ├─ #ABC123 - Jl. Sudirman     │
│  ├─ #DEF456 - Jl. Thamrin      │
│  └─ #GHI789 - Jl. Kuningan     │
│  [Pilih Kurir ▼] [Assign]      │
│                                  │
│ Batch #2 (2 orders, 6.1 km)    │
│  ├─ #JKL012 - Jl. Gatsu        │
│  └─ #MNO345 - Jl. Casablanca   │
│  [Pilih Kurir ▼] [Assign]      │
└─────────────────────────────────┘
```

### Kurir: Map View
```
┌─────────────────────────────────┐
│         🗺️  Maps View           │
├─────────────────────────────────┤
│  ╔═══════════════════════════╗ │
│  ║  📍 Toko (Start)          ║ │
│  ║         ↓                  ║ │
│  ║  ① Jl. Sudirman           ║ │
│  ║         ↓                  ║ │
│  ║  ② Jl. Thamrin            ║ │
│  ║         ↓                  ║ │
│  ║  ③ Jl. Kuningan           ║ │
│  ╚═══════════════════════════╝ │
│                                  │
│  Total Jarak: 4.2 km            │
│  [📱 Buka di Google Maps]       │
└─────────────────────────────────┘
```

## 🔗 Next Steps

1. ✅ Dependencies installed
2. ✅ Services implemented (geocoding, distance, optimizer)
3. ✅ Order model updated (auto-geocode on checkout)
4. ⏳ **Setup Google Maps API Key** (REQUIRED)
5. ⏳ Implement Admin batch assignment UI
6. ⏳ Implement Kurir map view
7. ⏳ Testing dengan real data

## 📞 Support

Jika ada error atau pertanyaan:
1. Check console log untuk error geocoding
2. Verify Google Maps API key sudah benar
3. Test dengan address yang jelas (include kota)
4. Rate limit Nominatim: max 1 req/sec (already handled)

---

**Status**: ✅ Core system ready, UI implementation in progress
**Last Update**: November 24, 2025
