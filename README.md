# Sleep Up

Belirlediğin saatte dikkat dağıtan uygulamaları kilitleyen, uyku ve odak
odaklı bir Flutter uygulaması. Android ve iOS'ta çalışır.

## Özellikler

- **Gece kilidi:** Seçilen günlerde, örn. 23:00–07:00 arası uygulamalar kilitlenir (gece yarısını geçen pencereler desteklenir).
- **İki kilit modu:** "Seçtiklerim" (yalnızca seçilenler) veya "Hepsi kilitli" (seçilenler istisna).
- **Rahatlama modu:** Kilitten 15/30/60 dk önce bildirim.
- **Şimdi uyu:** Programı beklemeden kilidi hemen başlatır, uyanma saatine kadar sürer.
- **Acil açma:** Gecede 0–2 hak, 5 dakikalık. Açmak için bir cümle yazmak gerekir (dürtüsel açmayı yavaşlatır).
- **Sıkı mod:** Kilit sırasında program değiştirilemez; Android'de Ayarlar uygulaması da kilitlenir, iOS'ta uygulama silme engellenir.
- **İlerleme:** Son 7 gece, seri, engellenen açılış ve acil açma sayıları, kurala dayalı öneri.
- **Gizlilik:** Hiçbir veri cihazdan çıkmaz; sunucu yoktur.

## Mimari

```
lib/                     Flutter arayüzü (iki platformda ortak)
  models/sleep_schedule.dart   Program ve zaman hesapları
  services/blocker_channel.dart MethodChannel 'sleepup/blocker'
  state/app_state.dart          Durum + kalıcı ayarlar (shared_preferences)
  screens/                      Bu gece, Program, Kilit, İlerleme, İzinler
android/…/sleep_up/      Kotlin
  LockStore.kt                  Kurallar, istatistik (SharedPreferences)
  BlockerAccessibilityService   Ön plandaki uygulamayı izler, kilit ekranını açar
  LockActivity.kt               Native kilit ekranı + acil açma
  WindDown.kt                   Rahatlama alarmı, açılışta yeniden kurma
  MainActivity.kt               Kanal
ios_screentime/          Swift (Screen Time API) — tam iOS sürümü için, Mac'te eklenir
  Shared/SharedStore.swift      App Group'ta ortak durum, kalkanı uygular
  Runner/BlockerPlugin.swift    Kanal, izinler, seçici, DeviceActivity zamanlama
  SleepUpMonitor/               Device Activity Monitor uzantısı (gece başla/bitir)
  SleepUpShield/                Shield Configuration uzantısı (kilit ekranı görünümü)
  SleepUpShieldAction/          Shield Action uzantısı (düğme, sayaç)
```

Platformlar kilitlemeyi farklı yapar:

| | Android | iOS |
|---|---|---|
| Algılama | Erişilebilirlik hizmeti, pencere değişimi | Sistem yapar (ManagedSettings kalkanı) |
| Zamanlama | Her olayda + 20 sn'de bir saat kontrolü | DeviceActivity (uygulama kapalıyken de çalışır) |
| Uygulama listesi | Yüklü uygulamalar | Apple'ın FamilyActivityPicker'ı (liste vermez) |
| Kilit ekranı | Tam ekran native Activity | Apple'ın kalkan ekranı (özelleştirilebilir) |
| Acil açma | Kilit ekranında ve uygulamada | Yalnızca Sleep Up uygulamasında |

## Kurulum

Gereken: Flutter 3.27+, Android Studio, (iOS için) Xcode 15+ ve **ücretli** Apple Developer hesabı.

```bash
cd sleep_up
flutter create --org com.sleepup --project-name sleep_up --platforms android,ios .
flutter pub get
flutter test
```

`flutter create .` yalnızca eksik dosyaları (Gradle, Xcode projesi, ikonlar) üretir, buradaki dosyaların üzerine yazmaz.

### Android

1. `flutter run` ile çalıştır.
2. İzinler ekranında "Erişilebilirlik hizmeti"ne izin ver: açılan ayarlarda **Sleep Up**'ı etkinleştir.
3. Android 13+'ta yandan yüklenen (sideload) uygulamalarda erişilebilirlik izni gri görünebilir: Ayarlar › Uygulamalar › Sleep Up › ⋮ › **Kısıtlı ayarlara izin ver**.
4. Bazı üreticilerde (Xiaomi, Huawei, Samsung) pil optimizasyonunu Sleep Up için kapatmak hizmetin kapanmasını önler.

**Google Play notu:** Erişilebilirlik API'si kullanan uygulamalar Play Console'da "Erişilebilirlik API'si beyanı" doldurmalı ve uygulama içinde açık bir açıklama göstermelidir (İzinler ekranındaki diyalog bu amaçla var). Dijital denge/uyku uygulamaları bu kullanım için kabul edilen kategoridedir, ama inceleme sıkıdır.

### iOS — ücretsiz deneme sürümü (Mac gerekmez)

`.github/workflows/build.yml` her push'ta GitHub'ın macOS makinelerinde imzasız
bir `SleepUp.ipa` üretir (Actions › son çalıştırma › Artifacts › **SleepUp-iPhone**).
Windows'ta **Sideloadly** ile ücretsiz Apple hesabınla iPhone'a yüklenir; 7 gün geçerlidir.
Bu sürümde native kilit katmanı yoktur: uygulama bunu algılar ve "Deneme sürümü" kartı gösterir.

### iOS — tam sürüm (kilit dahil, Mac + ücretli Apple Developer gerekir)

Önce `flutter create --platforms ios .` ile `ios/` klasörünü üret, sonra
`ios_screentime/` içindeki dosyaları aşağıdaki gibi Xcode projesine ekle
(aşağıdaki yollarda `ios/` yerine kaynak olarak `ios_screentime/` klasörünü kullan;
`ios_screentime/Runner/AppDelegate.swift`, üretilen `ios/Runner/AppDelegate.swift`'in yerine geçer).
Screen Time API, Xcode'da elle eklenmesi gereken üç uzantı ister:

1. `open ios/Runner.xcworkspace`
2. **Runner** hedefi › Signing & Capabilities:
   - Team'ini seç, Bundle ID: `com.sleepup.sleepUp` (ya da kendi ID'n).
   - **+ Capability › Family Controls**
   - **+ Capability › App Groups** › `group.com.sleepup.sleepup` (farklı bir ad seçersen `ios/Shared/SharedStore.swift` içindeki `SUConfig.appGroup`'u ve tüm `.entitlements` dosyalarını güncelle).
   - Build Settings › Code Signing Entitlements: `Runner/Runner.entitlements`
   - General › Minimum Deployments: **iOS 16.0**
3. `ios/Podfile` içinde `platform :ios, '16.0'` satırını aç.
4. Üç uzantı hedefi ekle (File › New › Target), her birinde iOS 16.0, aynı Team, Family Controls ve aynı App Group:
   - **Device Activity Monitor Extension** → adı `SleepUpMonitor`. Xcode'un ürettiği Swift dosyasını silip `ios/SleepUpMonitor/DeviceActivityMonitorExtension.swift`'i ekle.
   - **Shield Configuration Extension** → `SleepUpShield`, dosya: `ios/SleepUpShield/ShieldConfigurationExtension.swift`
   - **Shield Action Extension** → `SleepUpShieldAction`, dosya: `ios/SleepUpShieldAction/ShieldActionExtension.swift`
   - Her hedefin Code Signing Entitlements ayarını kendi klasöründeki `.entitlements` dosyasına yönlendir.
   - Uzantıların Info.plist'indeki `NSExtensionPrincipalClass` değerinin sınıf adlarıyla (`$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension` vb.) eşleştiğini kontrol et.
5. `ios/Shared/SharedStore.swift`'i projeye ekle ve **Target Membership**'te dört hedefi de (Runner + 3 uzantı) işaretle. `BlockerPlugin.swift`'i yalnızca Runner'a ekle.
6. Runner › Build Phases › **Embed Foundation Extensions** altında üç uzantının olduğunu doğrula. "Thin Binary" / "Embed" sırası yüzünden döngü hatası alırsan "Embed Foundation Extensions"ı "Run Script" adımlarının üstüne taşı.
7. Gerçek bir cihazda çalıştır (Screen Time API simülatörde çalışmaz).

**Daha yeni Flutter şablonu:** `AppDelegate.swift` içinde `FlutterImplicitEngineDelegate` / `didInitializeImplicitFlutterEngine` görüyorsan, buradaki `AppDelegate.swift`'i kullanmak yerine o fonksiyonun içine şunu ekle:

```swift
if let r = engineBridge.pluginRegistry.registrar(forPlugin: "BlockerPlugin") {
    BlockerPlugin.register(with: r)
}
```

**App Store notu:** Family Controls ile geliştirme hemen çalışır, ama **App Store / TestFlight dağıtımı için Apple'dan "Family Controls (Distribution)" yetkisi istemen gerekir** (developer.apple.com › Contact › Family Controls Entitlement Request). Bu yetki dört hedefin her bir Bundle ID'si için onaylanmalıdır ve onay birkaç hafta sürebilir; erkenden başvur.

## Bilinen sınırlar

- **iOS'ta "Hepsi kilitli" modu** Sleep Up'ı da kilitleyebilir; seçicide Sleep Up'ı istisnalara ekle. Telefon, Ayarlar gibi bazı sistem uygulamalarını Apple hiç kilitlemez.
- **iOS acil açma** 5 dakikadır ve DeviceActivity'nin 15 dk alt sınırı yüzünden "uyarı zamanı" ile geri kilitlenir. İstatistikteki "engellenen açılış", kalkandaki düğmeye basma sayısıdır.
- **iOS'ta haftanın belirli günleri** için gün bazlı DeviceActivity programları kullanılır; her gün seçiliyse tek bir günlük program kurulur (en güvenilir yol).
- **Android'de kullanıcı** erişilebilirlik iznini kapatarak kilidi devre dışı bırakabilir; sıkı mod kilit saatinde Ayarlar uygulamasını kilitleyerek bunu zorlaştırır ama Hızlı Ayarlar'dan ulaşılan bazı ekranlar yine açılabilir.
- Bu ortamda Flutter/Xcode/Android SDK bulunmadığı için kod derlenmeden yazıldı; ilk derlemede küçük düzeltmeler gerekebilir.

## Sonraki adımlar

- Yerelleştirme (`flutter_localizations`, şimdilik metinler Türkçe gömülü).
- Sabah raporu: açılış saatinde "dün gece nasıldı?" bildirimi.
- Sağlık entegrasyonu (HealthKit / Health Connect) ile gerçek uyku süresini istatistiğe ekleme.
- Widget'lar (iOS WidgetKit, Android Glance) ile ana ekranda geri sayım.
