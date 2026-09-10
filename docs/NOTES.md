# SmartPause — spike sonuçları (2026-09-10, macOS 26.5.2, Xcode 26.6)

## Spike A — aktif ses tespiti (`spikes/spikeA_audio.swift`) ✅
- Tap kurmaya gerek yok: `kAudioHardwarePropertyProcessObjectList` + her process için `kAudioProcessPropertyIsRunningOutput` (public, 14.2+).
- Ses kaydı izni İSTEMİYOR (test edildi, izinsiz çalıştı).
- Maliyet: ilk çağrı ~100 ms (HAL init), ısınmış ~14 ms. Sadece tuşa basınca çağrılacak → boşta 0 CPU.
- Doğrulama: `afplay` ve `say` çalarken pid'leri "▶︎ SES ÇIKARIYOR" olarak listelendi.
- Dikkat: tarayıcılar sesi helper process'ten çıkarır (`com.brave.Browser.helper`). Adapter eşlemesi bundle prefix'ine göre yapılmalı (helper → ana uygulama).

## Spike B — media key yakalama (`spikes/spikeB_eventtap.swift`) ⚠️ izin bekliyor
- `CGEventTap` + `NX_SYSDEFINED` (type 14, subtype 8, keycode 16 = PLAY). Derlendi.
- Accessibility izni verilmediği için tap kurulamadı. Test: Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik'e `spikes/spikeB`'yi (ya da Terminal'i) ekle, sonra `./spikeB` çalıştırıp tuşa bas.
- `--swallow` bayrağı tuşu yutar (Music açılmaz); bayraksız passthrough.

## Spike C — adapter'lar (`spikes/spikeC_adapters.sh`) ✅
- Spotify: `playpause` çalıştı. Not: `playpause` sonrası hemen okunan `player state` bayat dönüyor; ~200 ms sonra oku.
- Brave (Chromium): `execute tab javascript` ile tüm sekmeler taranıp çalan `<video>/<audio>` durduruldu (`paused:www.youtube.com`). Bu Mac'te "Allow JavaScript from Apple Events" zaten açık; onboarding'de kontrol edilmeli.
- Tuzak (yaşandı): "çalan yoksa ilkini başlat" mantığı kapalı YouTube videosunu istemeden başlattı → adapter sadece DURDURUR; başlatma kararı ses tespitine bağlı olmalı.
- Safari için `do JavaScript` yolu yazıldı, test edilmedi (Develop menüsü ayarı gerekir).

## Sonraki adım
Accessibility izni → Spike B canlı test → üç parçayı tek Swift paketinde birleştir (menü bar).

## v0.1 iskeleti (2026-09-10, aynı gün) — `swift build -c release` → `.build/release/SmartPause`
- Menü bar (NSStatusItem): ses çıkaran uygulama, son olay, etkin/kapalı toggle, Music engelleyici toggle, adapter listesi.
- Canlı doğrulama (simüle tuş + fiziksel MX Keys): Spotify 6/6 basış doğru toggle; Brave/YouTube durdur→sürdür→durdur 3/3; Music hiç açılmadı.
- Öğrenilenler:
  - Core Audio, durdurulan uygulamayı ~saniyeler boyunca "ses çıkarıyor" gösterir → adapter'ın kendi `isPlaying()` sorgusu şart (Spotify/Music/VLC). Tarayıcıda `pause()` zaten gerçek durumu görür; çalan yoksa `resume()`'a düşer.
  - Tap callback'i hafif tutulmalı: karar callback'te (~15-50 ms), AppleScript eylemi `DispatchQueue.main.async` ile.
  - Helper process → ana uygulama eşlemesi `responsibility_get_pid_responsible_for_pid` ile (izole, fail-safe).
  - Test tuzağı: sentetik tuş gönderen araç olayı teslim etmeden çıkarsa olay kaybolur (300 ms bekleme eklendi). Kayıp basışlar uygulamadan değil, bundan kaynaklandı.
- Güncelleme (aynı gün): Chrome 3/3 ve Safari 3/3 canlı doğrulandı; her ikisi de "Apple Events'ten JavaScript" ayarı gerektirir. Safari'nin sesi `com.apple.WebKit.GPU` process'inden çıkar, sorumlu-process eşlemesi Safari'yi doğru buldu.
- Plan B ölçümü: SmartPause kapalıyken sistem tuşu Chrome/YouTube'u doğru durdurdu ve Music açılmadı (tarayıcı çalarken "Şu An Çalan" kaydına giriyor). Bu yüzden tarayıcı JS izni isteğe bağlı: kapalıysa passthrough.
- Eski not: Chrome ve Safari kurulu ama test edilmedi (ikisinde de "Apple Events'ten JavaScript" ayarı açılmalı); Arc ve VLC kurulu değil. İki kaynak aynı anda çalıyorsa ilk adapter'lı olan durur (v0.2).
