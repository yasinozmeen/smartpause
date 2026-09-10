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
