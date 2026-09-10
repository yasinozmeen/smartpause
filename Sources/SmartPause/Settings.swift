import Foundation

/// Kullanıcı ayarları (UserDefaults). Ürün kararı (Yasin, 2026-09-10): çift kaynak davranışı seçilebilir.
enum MultiSourceMode: String, CaseIterable {
    /// PRD: ilk basış birinciyi durdurur; kısa aralıkla ikinci basış hedefi diğerine geçirir (birinci sürer, diğeri durur).
    case switchTarget
    /// İkinci basış diğer kaynağı da durdurur (hepsini sustur).
    case silenceAll

    var title: String {
        switch self {
        case .switchTarget: return "Hedefi diğer uygulamaya geçir"
        case .silenceAll:   return "Diğer uygulamayı da durdur (hepsini sustur)"
        }
    }
}

enum Settings {
    private static let d = UserDefaults.standard
    static var multiSourceMode: MultiSourceMode {
        get { MultiSourceMode(rawValue: d.string(forKey: "multiSourceMode") ?? "") ?? .switchTarget }
        set { d.set(newValue.rawValue, forKey: "multiSourceMode") }
    }
    static var showHUD: Bool {
        get { d.object(forKey: "showHUD") as? Bool ?? true }
        set { d.set(newValue, forKey: "showHUD") }
    }
    static var blockMusic: Bool {
        get { d.object(forKey: "blockMusic") as? Bool ?? true }
        set { d.set(newValue, forKey: "blockMusic") }
    }
}
