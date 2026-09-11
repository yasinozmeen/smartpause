import AppKit

/// İlk açılışta uygulama /Applications dışındaysa taşımayı önerir (Yasin, 2026-09-11).
/// Neden: Erişilebilirlik izni uygulamanın yoluna ve imzasına bağlıdır; İndirilenler'den çalışan kopya sonra taşınırsa izin düşer.
enum MoveToApplications {
    private static let neverKey = "neverAskMoveToApplications"

    /// Taşıma yapıldıysa uygulama yeniden başlatılır ve true döner (çağıran devam etmemeli).
    @discardableResult
    static func offerIfNeeded() -> Bool {
        let src = Bundle.main.bundleURL
        guard src.pathExtension == "app" else { return false }                    // `swift run` gibi paketsiz çalıştırma
        let applications = ["/Applications", NSHomeDirectory() + "/Applications"]
        if applications.contains(where: { src.path.hasPrefix($0 + "/") }) { return false }
        if UserDefaults.standard.bool(forKey: neverKey) { return false }

        let al = NSAlert()
        al.icon = NSApp.applicationIconImage
        al.messageText = L.moveTitle.t
        al.informativeText = L.moveBody.t
        al.addButton(withTitle: L.moveButton.t)
        al.addButton(withTitle: L.moveNotNow.t)
        al.addButton(withTitle: L.moveNever.t)
        NSApp.activate(ignoringOtherApps: true)
        switch al.runModal() {
        case .alertFirstButtonReturn: return move(from: src, to: URL(fileURLWithPath: "/Applications/SmartPause.app"))
        case .alertThirdButtonReturn: UserDefaults.standard.set(true, forKey: neverKey); return false
        default: return false
        }
    }

    private static func move(from src: URL, to dst: URL) -> Bool {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dst.path) { try fm.trashItem(at: dst, resultingItemURL: nil) }   // eski kopya çöpe
            try fm.copyItem(at: src, to: dst)
            try? fm.trashItem(at: src, resultingItemURL: nil)                                          // kaynağı (İndirilenler) çöpe
            Log.write("[move] taşındı: \(src.path) → \(dst.path)")
        } catch {
            Log.write("[move] taşınamadı: \(error)")
            let e = NSAlert(); e.messageText = L.moveFailed.t; e.informativeText = error.localizedDescription; e.runModal()
            return false
        }
        // Yeni kopyayı başlat, bunu kapat.
        let cfg = NSWorkspace.OpenConfiguration(); cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: dst, configuration: cfg) { _, _ in DispatchQueue.main.async { NSApp.terminate(nil) } }
        return true
    }
}
