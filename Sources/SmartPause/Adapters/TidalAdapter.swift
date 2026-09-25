import Foundation
import AppKit

/// TIDAL (Electron). AppleScript sözlüğü yok (Info.plist'te sdef yok; 2.43.2 incelendi, docs/NOTES.md). Kontrol, TIDAL'ın kendi
/// Playback menüsünden Accessibility API ile yapılır: SmartPause'un zaten sahip olduğu Erişilebilirlik izni yeter, yeni izin yok.
/// TIDAL bu menüyü her çalma durumu değişiminde yeniden kurar (`app/main/menu/MenuController.js`): ilk öğe çalarken "Pause",
/// dururken "Play" olur ve ikisi ayrı `pause()`/`resume()` çağırır (toggle değil). Yani ilk öğenin başlığı gerçek durumdur.
/// Öğeye AX ile basmak menüyü ekranda açmaz, TIDAL'ı öne getirmez. Tampon dolarken (STALLED) menü "Play" gösterir.
struct TidalAdapter: AppAdapter {
    let displayName = "TIDAL"
    /// Ses, kaliteye göre TIDALPlayer'dan (`com.tidal.desktop.player`, lossless/hi-res) ya da Chromium yardımcısından çıkar; önek ikisini de kapsar.
    let bundlePrefixes = ["com.tidal.desktop"]

    /// Menü başlıkları TIDAL'ın kendi dil ayarına göre değişir: `app/assets/locale/*.json` (17 dil) → t-play / t-pause / t-next / t-previous.
    /// Dört küme kesişmez ve Playback menüsündeki başka hiçbir öğe bunlarla aynı adı taşımaz (tüm dillerde kontrol edildi).
    static let playTitles: Set<String> = ["Play", "Abspielen", "Jouer", "Odtwórz", "Predvajaj", "Reproducir", "Reproduciraj", "Reprodukuj",
                                          "Spela", "Spill av", "Tocar", "Yürüt", "Пусни"]
    static let pauseTitles: Set<String> = ["Pause", "Pausa", "Pauza", "Pauziraj", "Premor", "Duraklat", "Пауза"]
    static let nextTitles: Set<String> = ["Next", "Weiter", "Suivant", "Siguiente", "Successivo", "Næste", "Neste", "Nästa", "Następny",
                                          "Próximo", "Dalje", "Sledeće", "Naslednje", "İleri", "Следващ/а"]
    static let previousTitles: Set<String> = ["Previous", "Zurück", "Précédent", "Anterior", "Precedente", "Forrige", "Föregående", "Poprzedni",
                                              "Voltar", "Prethodno", "Prejšnje", "Önceki", "Предишен/а"]
    /// AX menü çubuğu sırası: Apple, TIDAL, File, Edit, Playback, View, Navigation, Window, Help.
    static let playbackMenuIndex = 4
    /// Yanıt vermeyen TIDAL tuş kararını kilitlemesin (AX varsayılanı 6 sn). Süre öğe başınadır, türetilen öğeye geçmez
    /// (AXUIElement.h): okunan her öğeye ayrıca verilir.
    static let axTimeout: Float = 0.5

    /// Playback menüsünün ilk öğesinden durum: "Pause" → çalıyor, "Play" → çalmıyor, başka bir şey → menü bu değil (nil).
    static func playState(firstItemTitle t: String?) -> Bool? {
        guard let t else { return nil }
        return pauseTitles.contains(t) ? true : (playTitles.contains(t) ? false : nil)
    }
    /// Başlığı kümedeki bir öğenin sırası (Next/Previous; menü yeniden sıralansa da bulunur).
    static func itemIndex(in titles: [String], matching set: Set<String>) -> Int? { titles.firstIndex(where: set.contains) }

    func readiness() -> Readiness {
        guard isInstalled else { return .notInstalled }
        guard isRunning else { return .ready }
        guard AXIsProcessTrusted() else { return .unknown(L.helpNoPermission.t) }
        return playbackMenu() != nil ? .ready : .unknown(L.tidalMenuMissing.t)
    }
    /// Menü tanınmazsa (yeni bir TIDAL sürümü, desteklenmeyen dil, yanıt yok) tuş sisteme bırakılır; TIDAL "Şu An Çalan"dadır.
    func isControllable() -> Bool { playbackMenu() != nil }
    var notControllableReason: String { L.tidalMenuMissing.t }
    func isPlaying() -> Bool? { playbackMenu()?.playing }
    func pause() -> Bool { setPlaying(false) }
    func resume() -> Bool { setPlaying(true) }
    func next() -> Bool { pressItem(Self.nextTitles) }
    func previous() -> Bool { pressItem(Self.previousTitles) }

    /// Durum bilinçli: zaten istenen durumdaysa basmaz. Öğe okuma ile basma arasında menü yeniden kurulduysa (geçersiz öğe)
    /// menü yeniden okunup bir kez daha denenir; aynı öğeye körlemesine iki kez basmak durdurup yeniden başlatırdı.
    private func setPlaying(_ want: Bool) -> Bool {
        for _ in 0..<2 {
            guard let m = playbackMenu() else { Log.write("[tidal] Playback menüsü bulunamadı"); return false }
            if m.playing == want { return true }
            let r = AXUIElementPerformAction(m.items[0], kAXPressAction as CFString)
            Log.write("[tidal] \(want ? "Play" : "Pause") basıldı, AX sonucu \(r.rawValue)")
            // cannotComplete: eylem yine de çalışmış olabilir (AXUIElement.h); yeniden basılmaz.
            if r == .success || r == .cannotComplete { logOutcome(expecting: want); return true }
            if r != .invalidUIElement { return false }
        }
        return false
    }

    private func pressItem(_ titles: Set<String>) -> Bool {
        guard let items = playbackMenu()?.items, let names = try? items.map({ try Self.title($0) ?? "" }),
              let i = Self.itemIndex(in: names, matching: titles) else { return false }
        let r = AXUIElementPerformAction(items[i], kAXPressAction as CFString)
        return r == .success || r == .cannotComplete
    }

    /// Tanı: basıştan 1 sn sonra menü gerçekten döndü mü? Başka bir uygulama tam ekrandayken menü basışının sessizce boşa
    /// gittiği bildirildi (Beardie, Raycast #15293). Canlı testte logdan görülsün diye; kararı etkilemez.
    private func logOutcome(expecting want: Bool) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            let now = self.isPlaying()
            Log.write("[tidal] 1 sn sonra isPlaying=\(now.map { "\($0)" } ?? "nil")" + (now == want ? "" : " (beklenen \(want): tampon dolumu ya da basış boşa gitti)"))
        }
    }

    /// Playback menüsünün öğeleri ve ilk öğeden okunan durum. Her çağrıda taze okunur: TIDAL menüyü sık yeniden kurar, eski öğe geçersizleşir.
    /// Menü kendi başlığıyla değil (dile göre değişir) ilk öğesiyle tanınır; önce 4. sıraya, sonra diğerlerine bakılır (0: Apple menüsü).
    private func playbackMenu() -> (items: [AXUIElement], playing: Bool)? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundlePrefixes[0]).first?.processIdentifier else { return nil }
        do {
            guard let bar = try Self.element(Self.timed(AXUIElementCreateApplication(pid)), kAXMenuBarAttribute as CFString) else { return nil }
            let menus = try Self.children(bar)
            for i in [Self.playbackMenuIndex] + menus.indices.filter({ $0 != Self.playbackMenuIndex }) where i > 0 && i < menus.count {
                guard let menu = try Self.children(menus[i]).first else { continue }
                let items = try Self.children(menu)
                if let first = items.first, let playing = Self.playState(firstItemTitle: try Self.title(first)) { return (items, playing) }
            }
        } catch { Log.write("[tidal] yanıt vermiyor (AX zaman aşımı), menü taraması kesildi") }
        return nil
    }

    /// TIDAL yanıt vermedi (AX `cannotComplete`): taramanın geri kalanı her öğede yine zaman aşımını beklerdi, hemen kesilir.
    private struct NotResponding: Error {}
    private static func timed(_ e: AXUIElement) -> AXUIElement { AXUIElementSetMessagingTimeout(e, axTimeout); return e }
    private static func value(_ e: AXUIElement, _ attribute: CFString) throws -> CFTypeRef? {
        var v: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(e, attribute, &v)
        if r == .cannotComplete { throw NotResponding() }
        return r == .success ? v : nil
    }
    private static func element(_ e: AXUIElement, _ attribute: CFString) throws -> AXUIElement? {
        guard let v = try value(e, attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return timed(v as! AXUIElement)
    }
    private static func children(_ e: AXUIElement) throws -> [AXUIElement] {
        (try value(e, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []).map(timed)
    }
    private static func title(_ e: AXUIElement) throws -> String? { try value(e, kAXTitleAttribute as CFString) as? String }
}
