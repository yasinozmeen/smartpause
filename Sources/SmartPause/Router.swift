import Foundation
import AppKit

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

    /// Çift kaynak modu: ilk basıştan sonra bu süre içinde ikinci basış, diğer kaynağı da durdurur.
    var multiSourceWindow: TimeInterval = 1.5
    private var lastPauseAt: Date = .distantPast
    private var pausedInBurst: [AppAdapter] = []

    private func adapter(for p: AudioProcess) -> AppAdapter? {
        adapters.first { $0.matches(bundleID: p.responsibleBundleID) || $0.matches(bundleID: p.bundleID) }
    }

    /// Ses çıkaran + adapter'lı + gerçekten çalan kaynaklar, öncelik sırasıyla:
    /// 1) öndeki uygulama, 2) en son ses çıkarmaya başlayan, 3) liste sırası.
    private func rankedSources(_ playing: [AudioProcess], excluding: [AppAdapter]) -> [(AudioProcess, AppAdapter)] {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var seen = Set<String>(excluding.map(\.displayName))   // Core Audio bayat kaydı: az önce durdurduklarımız aday değil
        var list: [(AudioProcess, AppAdapter)] = []
        for p in playing {
            guard let a = adapter(for: p), !seen.contains(a.displayName) else { continue }
            if a.isPlaying() == false { continue }
            seen.insert(a.displayName); list.append((p, a))
        }
        return list.sorted { l, r in
            let lf = l.0.responsiblePID == front, rf = r.0.responsiblePID == front
            if lf != rf { return lf }
            let lt = AudioActivityTracker.shared.startTime(pid: l.0.pid) ?? .distantPast
            let rt = AudioActivityTracker.shared.startTime(pid: r.0.pid) ?? .distantPast
            return lt > rt
        }
    }

    /// Tap callback'inden çağrılır; hızlı karar verir, ağır işi (AppleScript) ana kuyruğa atar.
    /// true → tuş yutuldu (biz hallettik). false → passthrough.
    func handlePlayPause() -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        Log.write("[router] çalanlar: " + playing.map { "\($0.name)<\($0.responsibleBundleID)>" }.joined(separator: ", "))
        let inBurst = Date().timeIntervalSince(lastPauseAt) < multiSourceWindow
        let sources = rankedSources(playing, excluding: inBurst ? pausedInBurst : [])

        if let (_, a) = sources.first {
            if !a.isControllable() { report("\(a.displayName) kontrol edilemiyor (JS izni kapalı) → passthrough"); return false }
            if !inBurst { pausedInBurst = [] }
            lastPauseAt = Date()
            DispatchQueue.main.async { self.performPause(a, alsoSilenced: inBurst) }
            return true
        }
        if let p = playing.first(where: { adapter(for: $0) == nil }), sources.isEmpty, lastPaused == nil {
            report("Adapter yok: \(p.name) → passthrough"); return false
        }
        if let a = lastPaused {
            DispatchQueue.main.async { self.performResume(a) }
            return true
        }
        report("Ses yok, hedef yok → passthrough")
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

    private func performPause(_ a: AppAdapter, alsoSilenced: Bool) {
        if a.pause() {
            pausedInBurst.append(a)
            if alsoSilenced, let primary = pausedInBurst.first { lastPaused = primary; report("Bu da durduruldu: \(a.displayName) (sürdürülecek: \(primary.displayName))") }
            else { lastPaused = a; report("Durduruldu: \(a.displayName)") }
            return
        }
        // Durdurulacak bir şey yoktu (ör. tarayıcıda çalan media kalmamış) → sürdürme dene.
        if let l = lastPaused { performResume(l) } else { report("\(a.displayName) durdurulamadı") }
    }
    private func performResume(_ a: AppAdapter) {
        report(a.resume() ? "Sürdürüldü: \(a.displayName)" : "\(a.displayName) sürdürülemedi")
    }
    private func report(_ s: String) { lastEvent = s; Log.write("[router] \(s)"); onChange?() }
}
