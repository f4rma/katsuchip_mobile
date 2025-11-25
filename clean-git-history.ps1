# Script untuk Clean Git History - Firebase API Key

## BACKUP DULU SEBELUM MENJALANKAN!

# ===========================
# METODE 1: Menggunakan BFG Repo-Cleaner (RECOMMENDED)
# ===========================

# 1. Download BFG dari https://rtyley.github.io/bfg-repo-cleaner/
# Save as: bfg.jar di folder parent dari repository

# 2. Backup repository
Write-Host "Creating backup..." -ForegroundColor Yellow
cd ..
git clone --mirror https://github.com/f4rma/katsuchip_mobile.git katsuchip_mobile-backup.git
Write-Host "Backup created: katsuchip_mobile-backup.git" -ForegroundColor Green

# 3. Clean dengan BFG
Write-Host "Cleaning with BFG..." -ForegroundColor Yellow
cd katsuchip_mobile
java -jar ..\bfg.jar --delete-files firebase_options.dart
git reflog expire --expire=now --all
git gc --prune=now --aggressive
Write-Host "History cleaned!" -ForegroundColor Green

# 4. Push (HATI-HATI!)
Write-Host "WARNING: This will rewrite remote history!" -ForegroundColor Red
$confirm = Read-Host "Type 'YES' to force push"
if ($confirm -eq "YES") {
    git push --force --all
    git push --force --tags
    Write-Host "Done! Check GitHub to verify." -ForegroundColor Green
} else {
    Write-Host "Aborted. Run 'git push --force --all' manually when ready." -ForegroundColor Yellow
}

# ===========================
# METODE 2: Menggunakan git filter-branch (ALTERNATIF)
# ===========================

<# 
# JIKA BFG TIDAK BISA DIGUNAKAN:

Write-Host "Cleaning with git filter-branch..." -ForegroundColor Yellow

# Hapus dari seluruh history
git filter-branch --force --index-filter `
  "git rm --cached --ignore-unmatch lib/firebase_options.dart" `
  --prune-empty --tag-name-filter cat -- --all

# Force push
Write-Host "WARNING: This will rewrite remote history!" -ForegroundColor Red
$confirm = Read-Host "Type 'YES' to force push"
if ($confirm -eq "YES") {
    git push --force --all
    git push --force --tags
    Write-Host "Done! Check GitHub to verify." -ForegroundColor Green
}
#>

# ===========================
# VERIFIKASI
# ===========================

Write-Host "`n=== VERIFICATION ===" -ForegroundColor Cyan
Write-Host "1. Check GitHub repository - firebase_options.dart should not exist" -ForegroundColor White
Write-Host "2. Go to: https://github.com/f4rma/katsuchip_mobile/search?q=AIzaSy" -ForegroundColor White
Write-Host "3. Should show: 'We couldn't find any code matching'" -ForegroundColor White
Write-Host "`nIf the key still appears, wait a few minutes for GitHub to update index." -ForegroundColor Yellow
