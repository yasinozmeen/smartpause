import Foundation
import AppKit

/// Widget'ta gösterilen kaynak durumu.
struct SourceState {
    let adapter: AppAdapter
    let pid: pid_t
    let name: String
    let icon: NSImage?
    var isPlaying: Bool
    var isTarget: Bool
}

/// Tuş → hedef seçimi → adapter. Karar mantığı burada.
final class Router {
    let adapters: [AppAdapter] = [
        ScriptableAdapter.spotify, ScriptableAdapter.music, ScriptableAdapter.vlc,
        ChromiumAdapter.brave, ChromiumAdapter.chrome, ChromiumAdapter.arc, SafariAdapter(),
    ]
    /// Bir sonraki "sürdür" basışının gideceği hedef.
    private(set) var target: AppAdapter?
    private(set) var lastEvent = "—"
    /// Son basıştaki kaynaklar; widget bunu gösterir.
    private(set) var sources: [SourceState] = []
    var onChange: (() -> Void)?

    /// Çift kaynak modu: ilk basıştan sonra bu süre içinde ikinci basış "ikinci basış" sayılır.
    var multiSourceWindow: TimeInterval = 1.5
    private var lastPressAt: Date = .distantPast
    private var burstActive = false

    private func adapter(for p: AudioProcess) -> AppAdapter? {
        adapters.first { $0.matches(bundleID: p.responsibleBundleID) || $0.matches(bundleID: p.bundleID) }
    }
    private func index(of a: AppAdapter) -> Int? { sources.firstIndex { $0.adapter.displayName == a.displayName } }

    /// Ses çıkaran + adapter'lı + gerçekten çalan kaynaklar, öncelik sırasıyla:
    /// 1) öndeki uygulama, 2) en son ses çıkarmaya başlayan, 3) liste sırası.
    private func rankedSources(_ playing: [AudioProcess], excluding: [AppAdapter]) -> [SourceState] {
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
        }.map { p, a in
            SourceState(adapter: a, pid: p.responsiblePID, name: a.displayName,
                        icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: true, isTarget: false)
        }
    }

    /// Tap callback'inden çağrılır; hızlı karar verir, ağır işi (AppleScript) ana kuyruğa atar.
    /// true → tuş yutuldu (biz hallettik). false → passthrough.
    func handlePlayPause() -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        AudioActivityTracker.shared.observe(playing: Set(playing.map(\.pid)))
        Log.write("[router] çalanlar: " + playing.map { "\($0.name)<\($0.responsibleBundleID)>" }.joined(separator: ", "))
        let secondPress = burstActive && Date().timeIntervalSince(lastPressAt) < multiSourceWindow
        lastPressAt = Date()

        if secondPress, let t = target {
            // İkinci basış: mod'a göre.
            let others = sources.filter { $0.isPlaying && $0.adapter.displayName != t.displayName }
            if let next = others.first {
                switch Settings.multiSourceMode {
                case .switchTarget: DispatchQueue.main.async { self.performSwitch(from: t, to: next.adapter) }
                case .silenceAll:   DispatchQueue.main.async { self.performPause(next.adapter, keepTarget: t) }
                }
                return true
            }
            burstActive = false
            DispatchQueue.main.async { self.performResume(t) }
            return true
        }

        let ranked = rankedSources(playing, excluding: [])
        if let primary = ranked.first {
            if !primary.adapter.isControllable() { report("\(primary.name) kontrol edilemiyor (JS izni kapalı) → passthrough"); return false }
            sources = ranked
            burstActive = true
            DispatchQueue.main.async { self.performPause(primary.adapter, keepTarget: nil) }
            return true
        }
        burstActive = false
        if let p = playing.first(where: { adapter(for: $0) == nil }), target == nil {
            report("Adapter yok: \(p.name) → passthrough"); return false
        }
        if let t = target {
            DispatchQueue.main.async { self.performResume(t) }
            return true
        }
        report("Ses yok, hedef yok → passthrough")
        return false
    }

    /// Widget'tan: bu kaynağı hedef yap (çalıyorsa durdur, eski hedef sürsün — "geçiş").
    func userSelect(_ a: AppAdapter) {
        guard let t = target, t.displayName != a.displayName else { return }
        performSwitch(from: t, to: a)
    }
    /// Widget'tan: bu kaynağı başlat/durdur.
    func userToggle(_ a: AppAdapter) {
        guard let i = index(of: a) else { return }
        if sources[i].isPlaying { performPause(a, keepTarget: target) } else { performResume(a) }
    }

    /// Next/prev: ses çıkaran ve adapter'ı destekleyen uygulamaya gönderilir; yoksa passthrough.
    func handleTrackChange(forward: Bool) -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        for s in rankedSources(playing, excluding: []) {
            DispatchQueue.main.async {
                let ok = forward ? s.adapter.next() : s.adapter.previous()
                self.report(ok ? "\(forward ? "Sonraki" : "Önceki") parça: \(s.name)" : "\(s.name) parça değiştiremedi")
            }
            return true
        }
        report("Parça tuşu → passthrough"); return false
    }

    // MARK: - Eylemler (ana kuyruk)

    private func setState(_ a: AppAdapter, playing: Bool) {
        if let i = index(of: a) { sources[i].isPlaying = playing }
    }
    private func markTarget(_ a: AppAdapter?) {
        target = a
        for i in sources.indices { sources[i].isTarget = a.map { $0.displayName == sources[i].adapter.displayName } ?? false }
    }

    private func performPause(_ a: AppAdapter, keepTarget: AppAdapter?) {
        if a.pause() {
            setState(a, playing: false)
            markTarget(keepTarget ?? a)
            report(keepTarget == nil ? "Durduruldu: \(a.displayName)" : "Bu da durduruldu: \(a.displayName)")
            return
        }
        // Durdurulacak bir şey yoktu (tarayıcıda çalan media kalmamış) → sürdürme dene.
        setState(a, playing: false)
        if let t = target { performResume(t) } else { report("\(a.displayName) durdurulamadı") }
    }
    private func performResume(_ a: AppAdapter) {
        let ok = a.resume()
        if ok { setState(a, playing: true) }
        markTarget(a)
        report(ok ? "Sürdürüldü: \(a.displayName)" : "\(a.displayName) sürdürülemedi")
    }
    private func performSwitch(from old: AppAdapter, to new: AppAdapter) {
        let paused = new.pause(); if paused { setState(new, playing: false) }
        let resumed = old.resume(); if resumed { setState(old, playing: true) }
        markTarget(new)
        report("Hedef geçti: \(old.displayName) sürüyor, \(new.displayName) durdu")
    }
    private func report(_ s: String) { lastEvent = s; Log.write("[router] \(s)"); onChange?() }
}
