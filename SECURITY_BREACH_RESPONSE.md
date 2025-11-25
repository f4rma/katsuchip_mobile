# 🚨 KEAMANAN KRITIS - API Key Terekspos di GitHub

## ⚠️ Status: URGENT - Memerlukan Tindakan Segera

File `lib/firebase_options.dart` dengan Google API key `AIzaSyDoeeHEJHAOQSh66timbcgcAqY30ACifzc` telah ter-commit dan ter-push ke repository GitHub.

---

## ✅ Langkah yang Sudah Dilakukan

1. ✅ Menambahkan `lib/firebase_options.dart` ke `.gitignore`
2. ✅ Membuat file template `lib/firebase_options.dart.example`
3. ✅ Menghapus file dari git tracking dengan `git rm --cached`
4. ✅ File asli masih ada di local (tidak terhapus)

---

## 🔥 LANGKAH WAJIB - HARUS DILAKUKAN USER SEGERA

### 1. Revoke API Key di Google Cloud Console (PRIORITAS TERTINGGI)

**SEGERA lakukan ini untuk mencegah penyalahgunaan:**

1. Buka [Google Cloud Console](https://console.cloud.google.com/)
2. Pilih project **katsuchip-65298**
3. Navigasi ke: **APIs & Services** → **Credentials**
4. Cari API key: `AIzaSyDoeeHEJHAOQSh66timbcgcAqY30ACifzc`
5. Klik **⋮** (three dots) → **Delete** atau **Regenerate**
6. **Generate API key baru** untuk menggantikannya

### 2. Generate API Key Baru

1. Di Google Cloud Console → **APIs & Services** → **Credentials**
2. Klik **+ CREATE CREDENTIALS** → **API key**
3. **Restrict the key** (PENTING untuk keamanan):
   - Application restrictions: **Android apps**
   - Add package name: `com.example.katsuchip_app` (sesuaikan)
   - Add SHA-1 fingerprint dari keystore Anda
4. API restrictions: Enable hanya API yang dibutuhkan:
   - Firebase Authentication API
   - Cloud Firestore API
   - Firebase Storage API
   - Firebase Cloud Functions API
5. Save dan copy API key baru

### 3. Update Konfigurasi Firebase

1. Download `google-services.json` baru dari Firebase Console:
   - Firebase Console → Project Settings → General
   - Scroll ke **Your apps** → Android app
   - Klik **Download google-services.json**
   
2. Replace file `android/app/google-services.json` dengan yang baru

3. Update `lib/firebase_options.dart` dengan API key baru:
   ```dart
   apiKey: 'NEW_API_KEY_HERE',
   ```

### 4. Remove dari Git History (BFG Repo-Cleaner)

**PENTING: Backup repository sebelum melakukan ini!**

```powershell
# Install BFG Repo-Cleaner (jika belum)
# Download dari: https://rtyley.github.io/bfg-repo-cleaner/

# Buat backup
git clone --mirror https://github.com/f4rma/katsuchip_mobile.git katsuchip_mobile-backup.git

# Clone fresh copy
cd ..
git clone https://github.com/f4rma/katsuchip_mobile.git katsuchip_mobile-clean
cd katsuchip_mobile-clean

# Hapus file dari history dengan BFG
java -jar bfg.jar --delete-files firebase_options.dart

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (HATI-HATI: ini akan overwrite remote history)
git push --force
```

**⚠️ PERINGATAN:** Force push akan mengubah git history. Koordinasikan dengan semua kontributor!

### 5. Alternative: Menggunakan git filter-branch

Jika tidak bisa menggunakan BFG:

```powershell
# Hapus dari seluruh history
git filter-branch --force --index-filter "git rm --cached --ignore-unmatch lib/firebase_options.dart" --prune-empty --tag-name-filter cat -- --all

# Force push
git push --force --all
git push --force --tags
```

---

## 📋 Checklist Verifikasi

Setelah melakukan langkah di atas, verifikasi:

- [ ] API key lama sudah di-revoke di Google Cloud Console
- [ ] API key baru sudah di-generate dengan restrictions
- [ ] `google-services.json` baru sudah di-download dan replaced
- [ ] `lib/firebase_options.dart` sudah di-update dengan API key baru
- [ ] File `lib/firebase_options.dart` ada di `.gitignore`
- [ ] `git status` tidak menunjukkan `firebase_options.dart` sebagai tracked file
- [ ] Git history sudah dibersihkan dengan BFG atau filter-branch
- [ ] Force push berhasil ke GitHub
- [ ] Cek di GitHub: file `firebase_options.dart` sudah tidak ada di history

---

## 🔒 Best Practices untuk Mencegah di Masa Depan

1. **Selalu cek `.gitignore` sebelum commit file konfigurasi**
2. **Gunakan pre-commit hooks** untuk scan secret keys
3. **Enable GitHub secret scanning** di repository settings
4. **Jangan commit file dengan nama pattern:**
   - `*_options.dart`
   - `google-services.json`
   - `.env`
   - `*.key`, `*.keystore`, `*.jks`

5. **Setup git-secrets atau truffleHog** untuk pre-commit scanning:
   ```powershell
   # Install git-secrets
   # https://github.com/awslabs/git-secrets
   
   # Setup hooks
   git secrets --install
   git secrets --register-aws
   ```

---

## 🆘 Jika API Key Sudah Disalahgunakan

Monitor aktivitas di:
- [Firebase Console → Usage and Billing](https://console.firebase.google.com/)
- [Google Cloud Console → Billing](https://console.cloud.google.com/billing)

Jika ada aktivitas mencurigakan:
1. Revoke API key SEGERA
2. Review Firebase Security Rules
3. Check Firebase Authentication logs
4. Review Firestore/Storage access logs
5. Hubungi Google Cloud Support jika perlu

---

## 📞 Resources

- [Firebase Security Best Practices](https://firebase.google.com/docs/projects/api-keys)
- [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/)
- [GitHub - Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [git-secrets](https://github.com/awslabs/git-secrets)

---

**COMMIT SETELAH MEMBACA DAN MELAKUKAN LANGKAH DI ATAS**
