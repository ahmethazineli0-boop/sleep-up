# Sleep Up - otomatik kurulum ve calistirma
# Bu dosyayi dogrudan degil, "KURULUM-BURAYA-CIFT-TIKLA.bat" ile calistir.

$proj = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterRoot = Join-Path $env:USERPROFILE 'flutter'
$flutterBin = Join-Path $flutterRoot 'bin'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Adim($t) { Write-Host "`n==== $t ====" -ForegroundColor Yellow }
function Tamam($t) { Write-Host "  ✓ $t" -ForegroundColor Green }
function Dur($t) {
    Write-Host "`n  ✗ $t" -ForegroundColor Red
    Write-Host "  Bu pencerenin ekran görüntüsünü Claude'a gönder." -ForegroundColor Red
    Read-Host "`nKapatmak için Enter'a bas"
    exit 1
}

Write-Host "Sleep Up kurulumu başlıyor. İlk seferde 10-30 dakika sürebilir." -ForegroundColor Cyan
Write-Host "Soru sorarsa okuyup cevap ver (genelde 'y' ve Enter)." -ForegroundColor Cyan

# ---------- 1. Git ----------
Adim "1/6 Git kontrol ediliyor"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Tamam "Git zaten kurulu"
} else {
    Write-Host "  Git yok, Microsoft'un winget aracıyla kuruluyor (şartları sen onaylayacaksın)..."
    winget install --id Git.Git -e --source winget
    $env:Path = "C:\Program Files\Git\cmd;$env:Path"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Dur "Git kurulamadı. git-scm.com adresinden elle kurup bu dosyayı tekrar çalıştır."
    }
    Tamam "Git kuruldu"
}

# ---------- 2. Flutter ----------
Adim "2/6 Flutter kontrol ediliyor"
if (Test-Path (Join-Path $flutterBin 'flutter.bat')) {
    Tamam "Flutter zaten burada: $flutterRoot"
} elseif (Get-Command flutter -ErrorAction SilentlyContinue) {
    $flutterBin = Split-Path -Parent (Get-Command flutter).Source
    Tamam "Flutter zaten kurulu: $flutterBin"
} else {
    Write-Host "  Güncel Flutter sürümü bulunuyor..."
    try {
        $rel = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    } catch { Dur "Flutter sürüm listesi indirilemedi. İnternet bağlantını kontrol et." }
    $hash = $rel.current_release.stable
    $r = $rel.releases | Where-Object { $_.hash -eq $hash } | Select-Object -First 1
    $url = "$($rel.base_url)/$($r.archive)"
    $zip = Join-Path $env:TEMP 'flutter_sdk.zip'
    Write-Host "  Flutter $($r.version) indiriliyor (~1 GB, internetine göre uzun sürebilir)..."
    curl.exe -L --fail -o $zip $url
    if ($LASTEXITCODE -ne 0) { Dur "Flutter indirilemedi." }
    Write-Host "  Arşiv açılıyor (birkaç dakika)..."
    tar.exe -xf $zip -C $env:USERPROFILE
    if (-not (Test-Path (Join-Path $flutterBin 'flutter.bat'))) { Dur "Flutter arşivi açılamadı." }
    Remove-Item $zip -ErrorAction SilentlyContinue
    Tamam "Flutter kuruldu: $flutterRoot"
}

# Kalıcı PATH (yeni açılan terminallerde de 'flutter' çalışsın)
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
if ($userPath -notlike "*$flutterBin*") {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ";$flutterBin").TrimStart(';'), 'User')
    Tamam "Flutter PATH'e eklendi"
}
$env:Path = "$flutterBin;$env:Path"

# ---------- 3. Kontrol ----------
Adim "3/6 Sistem kontrolü (flutter doctor)"
flutter config --no-analytics | Out-Null
flutter doctor
Write-Host "`n  Not: 'Visual Studio' veya 'Chrome' satırlarındaki ✗ işaretleri önemli değil." -ForegroundColor Cyan

# ---------- 4. Lisanslar ----------
Adim "4/6 Android lisansları"
Write-Host "  Her soruya 'y' yazıp Enter'a bas." -ForegroundColor Cyan
flutter doctor --android-licenses
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Lisans adımı tamamlanamadı. Büyük ihtimalle Android Studio'da 'Command-line Tools' eksik." -ForegroundColor Red
    Write-Host "  Android Studio > More Actions > SDK Manager > SDK Tools sekmesi > 'Android SDK Command-line Tools' işaretle > OK" -ForegroundColor Red
    Write-Host "  Sonra bu dosyayı tekrar çalıştır. Şimdilik devam ediliyor..." -ForegroundColor Red
}

# ---------- 5. Proje ----------
Adim "5/6 Proje hazırlanıyor"
Set-Location $proj
flutter create --org com.sleepup --project-name sleep_up --platforms android,ios .
if ($LASTEXITCODE -ne 0) { Dur "Proje dosyaları oluşturulamadı." }
flutter pub get
if ($LASTEXITCODE -ne 0) { Dur "Paketler indirilemedi." }
flutter test
if ($LASTEXITCODE -ne 0) { Write-Host "  Testlerde hata var, yine de devam ediliyor." -ForegroundColor Red } else { Tamam "Testler geçti" }

# ---------- 6. Telefonda çalıştır ----------
Adim "6/6 Telefonda çalıştırma"
Write-Host @"
  Şimdi telefonda:
   1) Ayarlar > Telefon hakkında > 'Yapı numarası'na 7 kez dokun
   2) Ayarlar > Geliştirici seçenekleri > 'USB hata ayıklama'yı aç
   3) Telefonu kabloyla bilgisayara tak, telefonda çıkan soruya 'İzin ver' de
"@ -ForegroundColor Cyan

while ($true) {
    Read-Host "`nTelefonu bağladıysan Enter'a bas"
    $devs = flutter devices --machine 2>$null | Out-String
    if ($devs -match '"targetPlatform"\s*:\s*"android') { Tamam "Telefon bulundu"; break }
    Write-Host "  Telefon görünmüyor. Kabloyu değiştir, USB hata ayıklamayı kapatıp aç, telefondaki izin sorusuna bak." -ForegroundColor Red
    flutter devices
}

Write-Host "`n  Uygulama derlenip telefona yükleniyor. İlk sefer 3-10 dakika sürer..." -ForegroundColor Cyan
flutter run
Read-Host "`nBitti. Kapatmak için Enter'a bas"
