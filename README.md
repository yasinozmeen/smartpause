# SmartPause

macOS için akıllı media key yönlendirici. Play/pause tuşuna bastığında **o an gerçekten ses çıkaran** uygulama durur; Apple Music kendiliğinden açılmaz.

> "YouTube'u durdurmak istedim, Apple Music açıldı." — Bu uygulama o sorunu çözer.

## Nasıl çalışır

1. **Tuş yakalama** — `CGEventTap` ile play/pause/next/prev tuşları yakalanır (Erişilebilirlik izni).
2. **Ses tespiti** — Core Audio'nun public process API'si (macOS 14.2+) ile o an ses çıkaran process bulunur. Mikrofon/ses kaydı izni gerekmez, boşta CPU maliyeti sıfırdır.
3. **Hedefe komut** — Adapter mimarisi: Spotify, Apple Music, VLC ve tarayıcılar (Chrome, Brave, Arc, Safari) AppleScript ile kontrol edilir. Adapter'ı olmayan uygulamada tuş sisteme aynen bırakılır; asla ölü tuş kalmaz.
4. **Music engelleyici** — Apple Music kendiliğinden açılırsa hemen kapatılır (isteğe bağlı, menüden kapatılabilir).

Private API kullanılmaz. Tek istisna helper process → ana uygulama eşlemesi için `responsibility_get_pid_responsible_for_pid`; izole edilmiştir ve bulunamazsa güvenli şekilde devre dışı kalır.

## Kurulum

Homebrew (yakında):

```bash
brew install --cask yasinozmeen/smartpause/smartpause
```

Kaynaktan:

```bash
git clone https://github.com/yasinozmeen/smartpause && cd smartpause
./scripts/bundle.sh && open build/SmartPause.app
```

İlk açılışta:
- **Erişilebilirlik** izni istenir (zorunlu). Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik.
- İlk tuş basışında macOS her uygulama için bir kez **Otomasyon** izni sorar.
- Tarayıcı içindeki videoyu doğrudan kontrol etmek için Chrome/Brave'de Görünüm › Geliştirici › "Apple Events'ten JavaScript'e izin ver", Safari'de Geliştirme › Geliştirici Ayarları'nda aynı seçenek. **İsteğe bağlı:** kapalıysa tuş sisteme bırakılır ve tarayıcı çalarken zaten doğru çalışır.

## Durum

v0.1 — Spotify, Brave ve Chrome canlı doğrulandı. Safari, Arc ve VLC adapter'ları yazıldı, test bekliyor. Yol haritası ve teknik notlar: [docs/NOTES.md](docs/NOTES.md).

Gereksinim: macOS 14.2+ (Sonoma), Apple Silicon veya Intel.

## Lisans

MIT
