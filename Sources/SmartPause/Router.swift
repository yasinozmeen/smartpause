import Foundation

/// Tuş → hedef seçimi → adapter. Karar mantığı burada.
final class Router {
    let adapters: [AppAdapter] = [
        ScriptableAdapter.spotify, ScriptableAdapter.music, ScriptableAdapter.vlc,
        ChromiumAdapter.brave, ChromiumAdapter.chrome, ChromiumAdapter.arc, SafariAdapter(),
    ]
    /// En son durdurduğumuz adapter — tekrar basınca sürdürmek için.
    private(set) var lastPaused: AppAdapter?
    private(set) var lastEvent = "—"
    var onChange: (() -> Void)?

    /// Tap callback'inden çağrılır; hızlı karar verir, ağır işi (AppleScript) ana kuyruğa atar.
    /// true → tuş yutuldu (biz hallettik). false → passthrough.
    func handlePlayPause() -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        NSLog("[router] çalanlar: %@", playing.map { "\($0.name)<\($0.responsibleBundleID)>" }.joined(separator: ", "))
        var unknownApp: AudioProcess?
        for p in playing {
            guard let a = adapters.first(where: { $0.matches(bundleID: p.responsibleBundleID) || $0.matches(bundleID: p.bundleID) }) else {
                if unknownApp == nil { unknownApp = p }; continue
            }
            if a.isPlaying() == false { continue }   // bayat Core Audio kaydı
            if !a.isControllable() { report("\(a.displayName) kontrol edilemiyor (JS izni kapalı) → passthrough"); return false }
            DispatchQueue.main.async { self.performPause(a) }
            return true
        }
        if let a = lastPaused {
            DispatchQueue.main.async { self.performResume(a) }
            return true
        }
        if let p = unknownApp { report("Adapter yok: \(p.name) → passthrough") } else { report("Ses yok, hedef yok → passthrough") }
        return false
    }

    /// Next/prev: ses çıkaran ve adapter'ı destekleyen uygulamaya gönderilir; yoksa passthrough.
    func handleTrackChange(forward: Bool) -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        for p in playing {
            guard let a = adapters.first(where: { $0.matches(bundleID: p.responsibleBundleID) || $0.matches(bundleID: p.bundleID) }) else { continue }
            if a.isPlaying() == false { continue }
            DispatchQueue.main.async {
                let ok = forward ? a.next() : a.previous()
                self.report(ok ? "\(forward ? "Sonraki" : "Önceki") parça: \(a.displayName)" : "\(a.displayName) parça değiştiremedi")
            }
            return true
        }
        report("Parça tuşu → passthrough"); return false
    }

    private func performPause(_ a: AppAdapter) {
        if a.pause() { lastPaused = a; report("Durduruldu: \(a.displayName)"); return }
        // Durdurulacak bir şey yoktu (ör. tarayıcıda çalan media kalmamış) → sürdürme dene.
        if let l = lastPaused { performResume(l) } else { report("\(a.displayName) durdurulamadı") }
    }
    private func performResume(_ a: AppAdapter) {
        report(a.resume() ? "Sürdürüldü: \(a.displayName)" : "\(a.displayName) sürdürülemedi")
    }
    private func report(_ s: String) { lastEvent = s; NSLog("[router] %@", s); onChange?() }
}
