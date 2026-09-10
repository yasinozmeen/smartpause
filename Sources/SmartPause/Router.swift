import Foundation
import AppKit

/// Widget'ta gösterilen kaynak durumu (router içi; AppState'e yansıtılır).
struct SourceState {
    let adapter: AppAdapter
    let pid: pid_t
    let name: String
    let icon: NSImage?
    var isPlaying: Bool
    var isTarget: Bool
    var kind: AppState.SourceKind = .controlled
    var pulse = false
    var lastActivity = Date()   // son çaldığı ya da bizim dokunduğumuz an
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
    private var hint: String? = nil
    let state = AppState.shared
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
    /// 1) öndeki uygulama, 2) en son öne getirilen, 3) en son ses çıkarmaya başlayan.
    private func rankedSources(_ playing: [AudioProcess], excluding: [AppAdapter]) -> [SourceState] {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var seen = Set<String>(excluding.map(\.displayName))   // Core Audio bayat kaydı: az önce durdurduklarımız aday değil
        var list: [(AudioProcess, AppAdapter)] = []
        for p in playing {
            guard let a = adapter(for: p), !seen.contains(a.displayName) else { continue }
            let ip = a.isPlaying()
            Log.write("[rank] \(a.displayName) isPlaying=\(ip.map { "\($0)" } ?? "nil")")
            if ip == false { continue }
            seen.insert(a.displayName); list.append((p, a))
        }
        return list.sorted { l, r in
            let lf = l.0.responsiblePID == front, rf = r.0.responsiblePID == front
            if lf != rf { return lf }
            // 2) En son öne getirilen (kullanıcı niyeti), 3) en son ses çıkarmaya başlayan.
            let la = ActivationTracker.shared.lastActivation(pid: l.0.responsiblePID) ?? .distantPast
            let ra = ActivationTracker.shared.lastActivation(pid: r.0.responsiblePID) ?? .distantPast
            if la != ra { return la > ra }
            let lt = AudioActivityTracker.shared.startTime(pid: l.0.pid) ?? .distantPast
            let rt = AudioActivityTracker.shared.startTime(pid: r.0.pid) ?? .distantPast
            return lt > rt
        }.map { p, a in
            SourceState(adapter: a, pid: p.responsiblePID, name: a.displayName,
                        icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: true, isTarget: false)
        }
    }

    /// Ana kuyrukta çağrılır (tap tuşu zaten yutmuştur); false → tuş sisteme yeniden enjekte edilir.
    func handlePlayPause() -> Bool {
        if Settings.multiSourceMode == .switchKey { return handleSwitchKey() }
        return handleClassic()
    }

    // MARK: - Mod 1: tek basış geçir, çift basış başlat/durdur (Yasin modeli)
    private var pendingPress: DispatchWorkItem?
    static let doublePressWindow: TimeInterval = 0.35

    private func handleSwitchKey() -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        AudioActivityTracker.shared.observe(playing: Set(playing.map(\.pid)))
        let ranked = rankedSources(playing, excluding: [])
        mergeSources(ranked)
        if sources.isEmpty {
            if let p = playing.first(where: { adapter(for: $0) == nil }) { report("\(p.name) tanınmıyor → tuş sisteme bırakıldı"); return false }
            report("Ses yok, hedef yok → passthrough"); return false
        }
        if target == nil || index(of: target!) == nil { markTarget(ranked.first?.adapter ?? sources[0].adapter, reorder: false) }

        if let p = pendingPress {           // ikinci basış → çift basış: seçileni başlat/durdur
            p.cancel(); pendingPress = nil
            if let t = target { userInteraction = true; defer { userInteraction = false }
                if let i = index(of: t), sources[i].isPlaying { performPause(t, keepTarget: t) } else { performResume(t) } }
            return true
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingPress = nil
            self.singlePressSwitch()
        }
        pendingPress = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doublePressWindow, execute: work)
        return true
    }

    /// Tek basış: tek uygulama → başlat/durdur; birden çok → sıradakine geç (çalan durur, sıradaki başlar).
    private func singlePressSwitch() {
        guard let t = target, let ti = index(of: t) else { return }
        userInteraction = true; defer { userInteraction = false }
        if sources.count == 1 {
            if sources[ti].isPlaying { performPause(t, keepTarget: t) } else { performResume(t) }
            return
        }
        let next = sources[(ti + 1) % sources.count].adapter
        performSwitch(from: t, to: next)
    }

    // MARK: - Mod 2/3: klasik (basış durdurur; hızlı ikinci basış geçirir ya da susturur)
    private func handleClassic() -> Bool {
        let playing = AudioDetector.runningOutputProcesses()
        AudioActivityTracker.shared.observe(playing: Set(playing.map(\.pid)))
        Log.write("[router] çalanlar: " + playing.map { "\($0.name)<\($0.responsibleBundleID)>" }.joined(separator: ", "))
        let secondPress = burstActive && Date().timeIntervalSince(lastPressAt) < multiSourceWindow
        lastPressAt = Date()

        if secondPress, let t = target {
            let others = sources.filter { $0.isPlaying && $0.adapter.displayName != t.displayName }
            if let next = others.first {
                switch Settings.multiSourceMode {
                case .silenceAll: performPause(next.adapter, keepTarget: t)
                default: performSwitch(from: t, to: next.adapter)
                }
                return true
            }
            burstActive = false
            performResume(t)
            return true
        }

        let ranked = rankedSources(playing, excluding: [])
        mergeSources(ranked)
        if let primary = ranked.first {
            if !primary.adapter.isControllable() { report("\(primary.name) kontrol edilemiyor (JS izni kapalı) → passthrough"); return false }
            burstActive = true
            performPause(primary.adapter, keepTarget: nil)
            return true
        }
        burstActive = false
        if let p = playing.first(where: { adapter(for: $0) == nil }), target == nil {
            sources = sources.filter { $0.kind != .unknown } + [SourceState(adapter: ScriptableAdapter.spotify, pid: p.responsiblePID, name: p.name,
                                   icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: true, isTarget: false, kind: .unknown)]
            hint = "Bu uygulama için destek iste"
            report("\(p.name) tanınmıyor → tuş sisteme bırakıldı")
            return false
        }
        if let t = target { performResume(t); return true }
        report("Ses yok, hedef yok → passthrough")
        return false
    }

    func userSelect(named n: String) { if let a = adapters.first(where: { $0.displayName == n }) { userSelect(a) } }
    func userToggle(named n: String) { if let a = adapters.first(where: { $0.displayName == n }) { userToggle(a) } }

    /// Kaynak listesi kalıcıdır (Yasin kararı, 2026-09-10): bir kez görülen uygulama, kapanana kadar widget'ta kalır;
    /// duraklatılmış olsa da çift tıkla sürdürülebilir. Yeni çalanlar eklenir, çalmayanlar "Duraklatıldı" olur.
    /// Hafıza penceresi (Yasin, 2026-09-10): son 4 dakikada medya oynatan kaynak widget'ta kalır.
    private func mergeSources(_ ranked: [SourceState]) {
        for r in ranked {
            if let i = index(of: r.adapter) { sources[i].isPlaying = true; sources[i].lastActivity = Date() }
            else { sources.append(r) }
        }
        let playingNames = Set(ranked.map { $0.adapter.displayName })
        for i in sources.indices where !playingNames.contains(sources[i].adapter.displayName) {
            sources[i].isPlaying = false
        }
        // Uygulama kapandıysa listeden düşür.
        sources.removeAll {
            $0.kind == .unknown || NSRunningApplication(processIdentifier: $0.pid) == nil || !$0.adapter.isRunning
            || (!$0.isPlaying && Date().timeIntervalSince($0.lastActivity) > Settings.sourceMemory)
        }
        if let t = target, index(of: t) == nil { target = nil }
    }

    /// Widget'tan tek tık: bu kaynağı HEDEF yap (çalma durumu değişmez; bir sonraki tuş onu etkiler).
    func userSelect(_ a: AppAdapter) {
        guard index(of: a) != nil else { return }
        markTarget(a, reorder: false)
        burstActive = false
        report("Hedef: \(a.displayName)")
    }
    /// Widget'tan: bu kaynağı başlat/durdur.
    func userToggle(_ a: AppAdapter) {
        guard let i = index(of: a) else { return }
        userInteraction = true; defer { userInteraction = false }
        if sources[i].isPlaying { performPause(a, keepTarget: a) } else { performResume(a) }
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
        if let i = index(of: a) { sources[i].isPlaying = playing; sources[i].lastActivity = Date() }
    }
    private var userInteraction = false   // widget tıklaması sırasında sıra sabit
    private func markTarget(_ a: AppAdapter?, reorder: Bool = true) {
        let reorder = reorder && !userInteraction
        target = a
        for i in sources.indices { sources[i].isTarget = a.map { $0.displayName == sources[i].adapter.displayName } ?? false }
        // Sözleşme: tuşla geçişte hedef üste çıkar (260 ms). Kullanıcı tıklamasında SIRA SABİT kalır —
        // aksi halde çift tıkın ikinci tıkı yer değiştiren satıra denk geliyor (Yasin, 2026-09-10).
        if reorder, let i = sources.firstIndex(where: { $0.isTarget }), i != 0 { sources.insert(sources.remove(at: i), at: 0) }
    }

    private func performPause(_ a: AppAdapter, keepTarget: AppAdapter?) {
        if a.pause() {
            setState(a, playing: false)
            if let i = index(of: a) { sources[i].pulse = true }
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
    /// Yasin modeli geçişi: mevcut hedef çalıyorsa durur, sıradaki başlar, seçim ona geçer.
    private func performSwitch(from old: AppAdapter, to new: AppAdapter) {
        if Settings.multiSourceMode == .switchKey {
            if let i = index(of: old), sources[i].isPlaying, old.pause() { setState(old, playing: false); sources[i].pulse = true }
            let alreadyPlaying = index(of: new).map { sources[$0].isPlaying } ?? false
            let ok = alreadyPlaying || new.resume(); if ok { setState(new, playing: true) }
            markTarget(new)
            report(ok ? "Geçildi: \(new.displayName) çalıyor" : "\(new.displayName) başlatılamadı")
            return
        }
        performClassicSwitch(from: old, to: new)
    }
    private func performClassicSwitch(from old: AppAdapter, to new: AppAdapter) {
        let paused = new.pause(); if paused { setState(new, playing: false); if let i = index(of: new) { sources[i].pulse = true } }
        let resumed = old.resume(); if resumed { setState(old, playing: true) }
        markTarget(new)
        report("Hedef geçti: \(old.displayName) sürüyor, \(new.displayName) durdu")
    }
    private func report(_ s: String) {
        lastEvent = s; Log.write("[router] \(s)")
        // İpucu: iki kaynak varsa ikinci basışın ne yapacağını söyle.
        if Settings.multiSourceMode == .switchKey, sources.count > 1, let t = target, let ti = index(of: t) {
            let next = sources[(ti + 1) % sources.count]
            hint = "Tek basış: \(next.name)'e geç · Çift basış: \(t.displayName) başlat/durdur"
        } else if sources.count > 1, let t = target, let other = sources.first(where: { $0.adapter.displayName != t.displayName && $0.isPlaying }) {
            hint = Settings.multiSourceMode == .switchTarget ? "Bir daha basarsan \(other.name)'e geçerim" : "Bir daha basarsan \(other.name)'i de durdururum"
        } else if !sources.contains(where: { $0.kind == .unknown }) { hint = nil }
        let mapped = sources.map { AppState.Source(id: $0.adapter.displayName + ($0.kind == .unknown ? "#\($0.pid)" : ""), name: $0.name, icon: $0.icon, isPlaying: $0.isPlaying, isTarget: $0.isTarget, kind: $0.kind, pulse: $0.pulse) }
        for i in sources.indices { sources[i].pulse = false }
        let st = state
        DispatchQueue.main.async {
            st.sources = mapped; st.headline = s; st.hint = self.hint; st.lastEventAt = Date(); st.hudRevision += 1
            self.onChange?()
        }
    }
}
