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

## Çift kaynak modu (2026-09-10) ✅
- Karar: birincil hedef = öndeki uygulama, yoksa en son ses çıkarmaya başlayan (olay tabanlı `AudioActivityTracker`, polling yok). İlk basış birinciyi durdurur; 1,5 sn içinde ikinci basış diğerini de durdurur; sonraki basış birinciyi sürdürür.
- Canlı test (Spotify + Brave/YouTube, Brave önde): tek basış → sadece Brave durdu; tek basış → Brave sürdü; çift basış → Brave + Spotify durdu; tek basış → Brave sürdü. 4/4.
- İmza: ad-hoc imza her derlemede değiştiği için macOS Erişilebilirlik iznini sessizce düşürüyordu (ayarda açık görünüyor, `AXIsProcessTrusted` false). Çözüm: `scripts/bundle.sh` "Apple Development" sertifikası bulursa onunla imzalar; kimlik sabit kalır.
- Bilinen risk: ilk basışta callback içinde AppleScript sorguları (isPlaying/readiness) tap zaman aşımına bir kez takıldı, otomatik yeniden etkinleşti, tuş kaybolmadı. Kalıcı çözüm: "önce yut, işlenemezse tuşu yeniden enjekte et" deseni — callback'te hiç AppleScript çalıştırmamak. Yapılacak.

## Widget + seçilebilir çift kaynak modu (2026-09-10, Yasin kararı) ✅
- Ürün kararı: ikinci basış davranışı kullanıcı seçer. Varsayılan **"Hedefi diğer uygulamaya geçir"** (PRD: birinci sürer, diğeri durur); ikinci seçenek **"Hepsini sustur"**. Menüde "İki uygulama çalarken ikinci basış" alt menüsü.
- Widget (HUD): tuşa basınca menü barının sağ altında 2,6 sn belirir; kaynaklar, durumları ve hedef görünür. Tek tık → hedefi o uygulamaya geçir, çift tık → başlat/durdur (deneysel, kullanıcı testine göre değişecek). Görseller: `docs/widget-*.png`.
- Ölçüldü: macOS 26'da `NSStatusBarButton.window.frame` x=-4200 döndü (sahte konum) → widget simgeye değil ekranın sağ üstüne sabitlendi.
- Ölçüldü (Spike D): `kAudioProcessPropertyIsRunningOutput` için bildirim gelmiyor; `kAudioProcessPropertyIsRunning` geliyor ama seyrek. "En son başlayan" sıralaması yaklaşık; asıl sinyal öndeki uygulama.
- Kural netleşti: bir şey çalıyorsa basış onu durdurur; "hedef" yalnız sessizlikte neyin sürdürüleceğini belirler.

## Native Glass uygulaması (2026-09-10, akşam) ✅
- Tasarım sözleşmesi kanvasta: https://claude.ai/code/artifact/c45274ce-4c03-443b-aaa4-bf4699aa767c (A · Native Glass; B/C taslakları 2. sayfada).
- Widget: SwiftUI (`HUDView`) + `HUDPanel`. Giriş 380 ms yavaşlayarak, çıkış 220 ms hızlanarak, satır yer değiştirme 260 ms, simge nabzı 900 ms, azaltılmış hareket 150 ms yalnız opaklık. Hedef her zaman üstte. Görsel: `docs/widget-gecis-v2.png`.
- Sağ tık paneli: `SettingsPanel` + `PanelView` (SwiftUI). NSPopover KULLANILMADI: macOS 26 menü bar simgesi konumunu sahte veriyor (x = -4200; AX de aynı), popover köşeye düşüyordu. Konum tıklama anındaki fare x'inden; sol tık widget'ı gösterir. Görsel: `docs/panel.png`.
- Onboarding: `OnboardingView` + `OnboardingWindow` (NSWindow, floating; NSPanel deaktivasyonda gizlendiği için değiştirildi). İzin gelince 1→2 kendiliğinden geçer. Görseller: `docs/onboarding-*.png`.
- Sıralama sinyali: `ActivationTracker` (en son öne getirilen uygulama) eklendi; öndeki → en son etkinleşen → en son ses başlatan.
- Dev kancaları: `kill -USR1` panel, `kill -USR2` widget, `kill -INFO` onboarding (ekran görüntüsü testleri).
- Açık: widget'ta tek/çift tık davranışı kullanıcı testi bekliyor; ilk basış zaman aşımı sağlamlaştırması; Arc/VLC testi; uygulama ikonu.
- Yut → karar → yeniden enjekte deseni uygulandı (`MediaKeyTap`): callback'te AppleScript yok; passthrough gerekirse tuş işaretli olarak sisteme geri gönderilir. Tarayıcı `isPlaying()` artık gerçek (JS: çalan media var mı?).
- Kaynak hafızası (Yasin kararı): son 4 dk'da medya oynatan ve hâlâ açık olan kaynak widget'ta kalır (`Router.sourceMemory`); duraklatılmış olsa da çift tıkla sürdürülebilir.
- Barbee (menü çubuğu düzenleyici) simgeleri ekran dışına taşıdığı için sistem simge konumunu -4200 veriyor olabilir; çözümümüz bundan bağımsız.
- Ayarlar: widget kalma süresi (1,5/2,6/4/6/10 sn) ve kaynak hafızası (1/4/10/30 dk, 1 sa) panele eklendi. Panel ~870 pt; küçük ekranda kaydırma gerekebilir (açık).
- Widget tıklama: SwiftUI dokunma algılayıcıları etkinleştirmeyen panelde tetiklenmiyor; tıklama AppKit mouseDown ile yakalanıp satıra çevriliyor (NSHostingView flipped!). Tek tık = hedef, çift tık = başlat/durdur; canlı doğrulandı. Test aracı: spikes/simclick (System Events 'click at' AX tabanlı, paneli görmüyor).

## Tuş modeli netleşti (Yasin, 2026-09-10 akşam) — "tık" = play/pause TUŞU basışı, fare değil
- Yeni varsayılan mod `switchKey`: TEK basış → widget'taki sıradaki uygulamaya geç (çalan durur, sıradaki başlar, seçim geçer); tek uygulama varsa başlat/durdur. ÇİFT basış (350 ms içinde) → seçili uygulamayı başlat/durdur. Tek/çift ayrımı için tek basış 350 ms geciktirilir.
- Eski iki mod ("basış durdurur; hızlı ikinci basış geçirir / hepsini susturur") panelde seçenek olarak kaldı.
- Spotify/Music adapter'ları artık `play`/`pause` (durum bilinçli); `playpause` toggle geçişte ters etki yapıyordu. VLC: `if playing then play` / `if not playing then play`.
- Fare tıklaması widget'ta yine çalışıyor (tek tık hedef, çift tık başlat/durdur) ama Yasin'in kastı bu değildi.
- Bir kez tuş DOWN olayı loglanmadan geçti (Spotify'ı sistem durdurdu); 8/8 tekrar testinde kaçırma yok. Şüphe: log dosyasının çalışırken sıfırlanması. İzleniyor.

## Dil (2026-09-11)
- Tüm arayüz metinleri `Sources/SmartPause/L10n.swift` içindeki `L` enum'undan geçer: rawValue İngilizce kaynak, `L.tr` sözlüğü Türkçe. `L.key.t` düz metin, `L.key(arg)` biçimli (`%@`/`%d`).
- Varsayılan dil İngilizce (`Settings.language`, UserDefaults `language`). Panel › Kurulum sekmesindeki ilk kart dilden geçiş yaptırır; `AppState.language` yayınlandığı için görünümler anında yenilenir. Router'ın son olay başlığı bir sonraki tuşa kadar eski dilde kalır (kabul edildi).
- Yeni metin eklerken rawValue'ların benzersiz olması şart (enum kuralı) — "Ready"/"Apps" gibi ortak kelimeler tek case'le paylaşılır.

## Aralıklı tuş kaybı — kök neden ve çözüm (2026-09-11)
- Kanıt: 2026-09-10 23:35:41 DOWN/UP loglandı, router sustu; 23:37:41 (tam 120 sn sonra) sıradaki basış işlendi; 23:45:27 `[tap] DEVRE DIŞI (timeout)`. 120 sn = Apple Event varsayılan zaman aşımı → tarayıcı sekmesine gönderilen JS asılı kaldı.
- Neden: tap'in run loop kaynağı ANA iş parçacığındaydı ve AppleScript de ana kuyrukta koşuyordu. Ana kuyruk kilitlenince tap olayları karşılayamadı; macOS tap'i zaman aşımıyla kapattı, tuşlar ya kayboldu ya doğrudan sisteme gitti (Spotify'ın "kendi kendine" açılıp kapanması buydu).
- Çözüm: (1) `MediaKeyTap` kendi Thread + CFRunLoop'unda; karar `Router.queue` (seri, userInteractive) üzerinde. (2) Router'ın tüm işi (Core Audio, AppleScript, kaynak listesi, 350 ms çift basış zamanlayıcısı) o kuyrukta; arayüz çağrıları `userSelect/userToggle(named:)` kuyruğa aktarılır; `report()` ana kuyruğa yalnız AppState güncellemesi gönderir. (3) `AppleScript.runDetailed` her kaynağı `with timeout of 4 seconds` ile sarar; 400 ms üstü çağrı `[applescript] YAVAŞ` diye loglanır. (4) Her tuş kararı `[tap] karar … (N ms)` satırıyla ölçülür.
- Ek bulgu: `ScriptableAdapter.pause()/resume()` hâlâ `playpause` toggle kullanıyordu (playCommand/pauseCommand tanımlı ama kullanılmıyordu) → duran Spotify'ı "durdur" çağrısı başlatabiliyordu. Artık açık `pause`/`play`.
- Ölçüm: tek kaynak 6/6 (~50 ms), Spotify+Brave 6/6 geçiş (90–160 ms), çift basış durdur/sürdür doğru.

## Bildirim banner'ından kaçınma (2026-09-11)
- CGWindowList Bildirim Merkezi'ni tam ekran tek pencere gösterir (konum yok). AX ağacında `AXNotificationCenterBanner` / `AXNotificationCenterAlert` alt-rolü gerçek çerçeveyi verir (sol-üst orijin, birincil ekran). `NotificationBanners.lowestEdge(on:)`.
- HUD dinlenme yüksekliği = menü çubuğu altı ya da en alttaki banner'ın 8 pt altı. Görünürken 0,5 sn'de bir kontrol; banner gelince iner, gidince boşluğu doldurmak için çıkar (320 ms, aynı eğri).

## Kalıcı kaynak hafızası (2026-09-13)
Widget listesi her rapor sonrası `UserDefaults` → `rememberedSources` (ad, son etkinlik, hedef mi) olarak yazılır. Açılışta hafıza penceresi (`sourceMemory`) dolmamış ve uygulaması hâlâ açık kaynaklar "Duraklatıldı" olarak geri gelir, hedef korunur. Sonuç: yeniden başlatmadan sonraki ilk basış macOS'un hatırladığı uygulamaya değil, en son kullanılana gider. Testler: `testSourcesSurviveRestart`, `testExpiredSourcesAreNotRestored` (mutasyonla doğrulandı).

## Panel küçük ekranda (2026-09-13)
İçerik `NSScrollView` (üstten hizalı `FlippedClipView`) içinde. Panel yüksekliği = min(içerik, ekranın görünür yüksekliği − ok − 14). Açıkken sekme değişince üst kenar sabit kalarak yeniden boyutlanır (`frameDidChangeNotification`). 600 pt sınırla görsel doğrulandı; büyük ekranda davranış değişmedi (941 pt).

## Çoklu ekran: widget farenin ekranında (2026-09-13)
Hata: çift ekranda widget Mac ekranına geliyordu. `NSRect.contains` üst/sağ kenarı dışarıda sayar; fare menü çubuğu hizasına dayanınca (y = maxY) hiçbir ekran eşleşmiyor, kod `NSScreen.main`'e düşüyordu (menü bar uygulamasında bu odaktaki pencerenin ekranı). `NSScreen.underMouse` kenarları dahil sayar, yoksa en yakın ekranı seçer; widget ve panel ikisi de kullanır. Fare DELL üst kenarı, DELL sağ kenarı ve Mac ekranı ortasına götürülerek ölçüldü, üçü de doğru ekran. HUD logu artık `ekran=… fare=…` yazar.

Takip (2026-09-13): widget açıkken 0,15 sn'de bir `NSScreen.underMouse` kontrol edilir; ekran değişince eski ekranda sağa kayıp çıkar, yeni ekranda sağ kenardan girer ve süre baştan başlar. Widget'ın hangi ekranda olduğu `currentScreen`'den okunur; pencere kesişiminden okunmaz, çünkü sağa taşan 40 pt komşu ekrana değer (Mac ekranındaki widget kapanırken DELL'in sağına kayıyordu). Ölçüm: DELL'de aç → fare Mac'e → pencere x=-296; fare DELL'e → x=2264.

## Tek kaynakta çift basış: müzik uygulaması (2026-09-13)
Widget'ta tek kaynak varken (ör. yalnız Brave) çift basış tek basışla aynı işi yapıyordu. Artık `musicApp` (Spotify) çalar: kaynak çalıyorsa durur; Spotify açıksa `play`, kapalıysa `NSWorkspace.openApplication(activates: false)` ile arka planda açılır, AppleScript yanıt verene kadar (≤10 sn) beklenir, sonra `play`. 0,8 sn sonra `player state` ile doğrulanır, çalmıyorsa 2-3 kez yeniden denenir. Şartlar: tek kaynak, kontrol edilen tür, müzik uygulamasının kendisi değil, Spotify kurulu. İki kaynak varken davranış değişmedi. İpucu: "Çift basış: Spotify çal". Testler: 3 (mutasyonla doğrulandı). Canlı uçtan uca test Yasin'de (müzik çalmayı ben tetiklemedim).

## TIDAL adapter (2026-09-25, issue #2)
TIDAL 2.43.2 (Electron 43, `com.tidal.desktop`) paketi açılıp incelendi; canlı test YOK (bu ortamda Mac yok), log bekleniyor.
- AppleScript yok: Info.plist'te `NSAppleScriptEnabled`/`OSAScriptingDefinition` yok, pakette `.sdef` yok. Yerel port, oynatma deep link'i de yok (`tidal://` yalnız gezinme).
- Yol: TIDAL'ın kendi **Playback** menüsü, Accessibility API ile (yeni izin yok; System Events kullanılmadı, o yeni bir Otomasyon izni isterdi). `app/main/menu/playbackMenu.js`: ilk öğe çalarken "Pause", dururken "Play"; ikisi aynı anda yok. `MenuController.js` menüyü her `playing` değişiminde `Menu.buildFromTemplate` + `setApplicationMenu` ile yeniden kurar, yani başlık bayatlamaz ve gerçek durumu verir. Pause/Play ayrı `pause()`/`resume()` çağırır (toggle değil) ve pencere odağı istemez (`menuClick`, `focusedMenuClick` değil). Tampon dolarken (STALLED) ve oturum kapalıyken menü "Play" gösterir.
- Menü dile göre değişir (TIDAL'ın kendi dil ayarı, 17 dil `app/assets/locale/*.json`; tr: "Kayıttan yürütme" / Yürüt / Duraklat). Bu yüzden menü kendi başlığıyla değil, ilk öğesinin Play/Pause kümesinde olmasıyla tanınır (önce menü çubuğunda 4. sıra: Apple, TIDAL, File, Edit, Playback…). Next/Previous da başlıkla bulunur. Kümeler kesişmiyor, menüdeki başka öğeyle de çakışmıyor (tüm dillerde kontrol edildi). `AXEnabled`'a güvenilmez: Electron durumu yalnız menü açılırken uygular.
- Ses: lossless/hi-res'te `TIDALPlayer` (`com.tidal.desktop.player`, AppKit'siz yardımcı, `NSRunningApplication` değil), LOW/HIGH ve videoda Chromium yardımcısı. `com.tidal.desktop` öneki ikisini de kapsar. Sorumlu-process eşlemesi tutmazsa kaynak yardımcının pid'inde kalıp `isAlive` ile düşerdi; `Router.owner(of:)` artık açık uygulamanın pid'ini alır (test: `testSourceFromNonAppHelperBindsToRunningApp`).
- Menü tanınmazsa (yeni sürüm, yeni dil, TIDAL yanıt vermiyor) `isControllable` false; widget "TIDAL kontrol edilemiyor (Oynatma menüsü tanınmadı)" der, panelde de aynı not (neden artık adapter'dan: `notControllableReason`, varsayılan "JS izni kapalı"). Tuş sisteme gider (TIDAL "Şu An Çalan"da): klasik modlarda çalarken (eskisi gibi), switchKey'de widget'ta tek kaynak varken ve çift basışın açacağı müzik uygulaması yokken (her basış ona gideceği için). next/previous başaramazsa da tuş sisteme gider (AppAdapter sözleşmesi; tarayıcılarda da). Testler: 3 (mutasyonla doğrulandı).
- Açık kalan (tarayıcıda JS izni kapalıyken de böyleydi, ayrı iş): birden çok kaynakta ya da müzik uygulaması varken komut kontrol edilemeyen hedefe düşerse tuş yutulur. İlk denemede switchKey'de "çalan ya da hedef kontrol edilemiyorsa passthrough" yazıldı; Spotify↔YouTube geçişini ve çift basışla Spotify'ı bozduğu için geri alındı. Doğrusu komut anında karar vermek (ertelenen tek basışta yeniden enjekte).
- AX zaman sınırı (0,5 sn) öğe başınadır, türetilen öğeye geçmez (AXUIElement.h): okunan her öğeye ayrıca verilir; TIDAL `cannotComplete` dönerse tarama kesilir (yoksa 8 menü × 6 sn router kuyruğunu kilitleyebilirdi).
- Kayıt sırası: TIDAL tarayıcılardan sonra. Onboarding ilk 4 kurulu uygulamayı gösteriyor; önde olsaydı ayar isteyen tarayıcı satırını dışarı itebilirdi.
- Bilinen risk (başkalarının raporu, doğrulanmadı): başka bir uygulama tam ekrandayken menü basışı sessizce boşa gidebilir (Beardie, Raycast #15293). Her basıştan 1 sn sonra `[tidal] 1 sn sonra isPlaying=…` logu bunu gösterir.
- Canlı testte bakılacak: arka planda / gizli (⌘H) / pencere kapalıyken basış çalışıyor mu, menü ekranda açılıyor mu; lossless ve HIGH'da Core Audio hangi pid'i veriyor, duraklatınca ses çıkışı kapanıyor mu; tek basış, çift basış, next/previous.
- TIDAL güncellenince (otomatik güncellenir) `playbackMenu.js` ve `locale/*.json` yeniden kontrol edilmeli: `brew` cask'taki zip'i açıp `npx @electron/asar extract Contents/Resources/app.asar out`.
