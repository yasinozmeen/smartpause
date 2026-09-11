import Foundation

/// Kullanıcı ayarları (UserDefaults). Ürün kararı (Yasin, 2026-09-10): çift kaynak davranışı seçilebilir.
enum MultiSourceMode: String, CaseIterable {
    /// Yasin modeli (2026-09-10): TEK basış diğer uygulamaya geçer (çalan durur, diğeri başlar); ÇİFT basış seçileni başlatır/durdurur.
    /// Tek/çift ayrımı için 350 ms bekleme.
    case switchKey
    /// PRD: ilk basış birinciyi durdurur; kısa aralıkla ikinci basış hedefi diğerine geçirir (birinci sürer, diğeri durur).
    case switchTarget
    /// İkinci basış diğer kaynağı da durdurur (hepsini sustur).
    case silenceAll

    var title: String {
        switch self {
        case .switchKey:    return L.modeSwitchKey.t
        case .switchTarget: return L.modeSwitchTarget.t
        case .silenceAll:   return L.modeSilenceAll.t
        }
    }
}

/// Menü çubuğu simgesi seçenekleri (Yasin isteği, 2026-09-10).
enum MenuBarIcon: String, CaseIterable {
    case playpauseFilled = "playpause.circle.fill", playpause = "playpause.fill", waveform = "waveform", speaker = "speaker.wave.2.fill"
    var title: String {
        switch self { case .playpauseFilled: return L.iconCircle.t; case .playpause: return L.iconPlain.t; case .waveform: return L.iconWave.t; case .speaker: return L.iconSpeaker.t }
    }
    /// Kapalı/izinsiz durumda kullanılacak zayıf sürüm.
    var dimmed: String {
        switch self { case .playpauseFilled: return "playpause.circle"; case .playpause: return "playpause"; case .waveform: return "waveform"; case .speaker: return "speaker.wave.2" }
    }
}

enum Settings {
    /// Arayüz dili. Varsayılan İngilizce (ürün kararı 2026-09-11).
    static var language: Language {
        get { Language(rawValue: d.string(forKey: "language") ?? "") ?? .en }
        set { d.set(newValue.rawValue, forKey: "language") }
    }
    static var menuBarIcon: MenuBarIcon {
        get { MenuBarIcon(rawValue: d.string(forKey: "menuBarIcon") ?? "") ?? .playpauseFilled }
        set { d.set(newValue.rawValue, forKey: "menuBarIcon") }
    }
    private static let d = UserDefaults.standard
    static var multiSourceMode: MultiSourceMode {
        get { MultiSourceMode(rawValue: d.string(forKey: "multiSourceMode") ?? "") ?? .switchKey }
        set { d.set(newValue.rawValue, forKey: "multiSourceMode") }
    }
    static var showHUD: Bool {
        get { d.object(forKey: "showHUD") as? Bool ?? true }
        set { d.set(newValue, forKey: "showHUD") }
    }
    static var onboardingDone: Bool {
        get { d.bool(forKey: "onboardingDone") }
        set { d.set(newValue, forKey: "onboardingDone") }
    }
    static var launchAtLogin: Bool {
        get { d.bool(forKey: "launchAtLogin") }
        set { d.set(newValue, forKey: "launchAtLogin") }
    }
    /// Widget'ın ekranda kalma süresi (saniye). Varsayılan 2,6.
    static let hudDurationOptions: [Double] = [1.5, 2.6, 4, 6, 10]
    static var hudDuration: Double {
        get { let v = d.double(forKey: "hudDuration"); return v > 0 ? v : 2.6 }
        set { d.set(newValue, forKey: "hudDuration") }
    }
    /// Kaynak hafızası (saniye): son ne kadarlık sürede medya oynatan uygulama widget'ta kalır. Varsayılan 4 dk.
    static let sourceMemoryOptions: [Double] = [60, 240, 600, 1800, 3600]
    static var sourceMemory: Double {
        get { let v = d.double(forKey: "sourceMemory"); return v > 0 ? v : 240 }
        set { d.set(newValue, forKey: "sourceMemory") }
    }
    static var blockMusic: Bool {
        get { d.object(forKey: "blockMusic") as? Bool ?? true }
        set { d.set(newValue, forKey: "blockMusic") }
    }
}
