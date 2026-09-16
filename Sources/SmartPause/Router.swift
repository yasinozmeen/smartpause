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
    static let defaultAdapters: [AppAdapter] = [
        ScriptableAdapter.spotify, ScriptableAdapter.music, ScriptableAdapter.vlc,
        ChromiumAdapter.brave, ChromiumAdapter.chrome, ChromiumAdapter.arc, SafariAdapter(),
    ]
    let adapters: [AppAdapter]
    /// Ses çıkaran process'leri veren kaynak (üretimde Core Audio; testlerde sahte liste).
    private let detect: () -> [AudioProcess]
    /// Kaynağın process'i hâlâ hayatta mı (üretimde NSRunningApplication; testlerde hep true).
    private let isAlive: (SourceState) -> Bool

    /// Kaynak hafızasının diske yazıldığı yer (nil: kalıcı hafıza yok). Testler kendi geçici suite'ini verir.
    private let memory: UserDefaults?
    /// Açık bir uygulamanın pid'i ve simgesi (geri yüklerken). Testlerde sahte.
    private let findRunning: (AppAdapter) -> (pid: pid_t, icon: NSImage?)?
    private let bundleIDForPID: (pid_t) -> String
    static let memoryKey = "rememberedSources"

    init(adapters: [AppAdapter] = Router.defaultAdapters,
         detect: @escaping () -> [AudioProcess] = AudioDetector.runningOutputProcesses,
         isAlive: @escaping (SourceState) -> Bool = { NSRunningApplication(processIdentifier: $0.pid) != nil && $0.adapter.isRunning },
         memory: UserDefaults? = .standard,
         findRunning: @escaping (AppAdapter) -> (pid: pid_t, icon: NSImage?)? = { a in
             NSRunningApplication.runningApplications(withBundleIdentifier: a.bundlePrefixes[0]).first.map { ($0.processIdentifier, $0.icon) }
         },
         bundleIDForPID: @escaping (pid_t) -> String = { pid in
             let rpid = ResponsibleProcess.pid(for: pid)
             return NSRunningApplication(processIdentifier: rpid)?.bundleIdentifier
                 ?? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
         },
         musicApp: AppAdapter? = ScriptableAdapter.spotify,
         launchApp: @escaping (AppAdapter, @escaping (Bool) -> Void) -> Void = Router.launchInBackground,
         connectActivityTracker: Bool = true) {
        self.adapters = adapters; self.detect = detect; self.isAlive = isAlive; self.memory = memory; self.findRunning = findRunning
        self.bundleIDForPID = bundleIDForPID; self.musicApp = musicApp; self.launchApp = launchApp
        restoreSources()
        if connectActivityTracker {
            AudioActivityTracker.shared.onActivityChange = { [weak self] pid, isRunning in
                self?.handleAudioActivity(pid: pid, isRunning: isRunning)
            }
        }
    }

    // MARK: - Çift basışla müzik uygulaması (Yasin, 2026-09-13)
    /// Widget'ta tek kaynak varken (ör. yalnız Brave) çift basış tek basışla aynı işi yapıyordu. Artık müzik uygulamasını
    /// (Spotify) çalar: kaynak çalıyorsa durur; Spotify açıksa kaldığı yerden sürer, kapalıysa arka planda açılıp sürer.
    private let musicApp: AppAdapter?
    private let launchApp: (AppAdapter, @escaping (Bool) -> Void) -> Void
    /// Açılış/sürdürme sonrası "gerçekten çalıyor mu" kontrolünden önce bekleme (Spotify `play`'i birkaç yüz ms'de uygular).
    static var musicVerifyDelay: TimeInterval = 0.8

    /// Çift basışın müzik uygulamasını çalacağı durum: widget'ta tek, kontrol edilen, müzik uygulaması olmayan bir kaynak.
    private func eligibleMusicApp() -> AppAdapter? {
        guard sources.count == 1, sources[0].kind == .controlled, let m = musicApp,
              sources[0].adapter.displayName != m.displayName, m.isInstalled else { return nil }
        return m
    }

    private func playMusicApp(_ m: AppAdapter, from t: AppAdapter) {
        if let i = index(of: t), sources[i].isPlaying, t.pause() { setState(t, playing: false); sources[i].pulse = true }
        if m.isRunning { resumeMusic(m, attemptsLeft: 2); return }
        report(L.musicOpening(m.displayName))
        launchApp(m) { [weak self] ok in
            guard let self else { return }
            self.queue.async { ok ? self.resumeMusic(m, attemptsLeft: 3) : self.report(L.startFailed(m.displayName)) }
        }
    }

    /// `play` gönderir, kısa süre sonra gerçekten çaldığını doğrular; çalmıyorsa birkaç kez daha dener.
    private func resumeMusic(_ m: AppAdapter, attemptsLeft: Int) {
        _ = m.resume()
        if index(of: m) == nil {
            let run = findRunning(m)
            sources.append(SourceState(adapter: m, pid: run?.pid ?? 0, name: m.displayName, icon: run?.icon, isPlaying: false, isTarget: false))
        }
        markTarget(m)
        queue.asyncAfter(deadline: .now() + Self.musicVerifyDelay) { [weak self] in
            guard let self else { return }
            let playing = m.isPlaying() ?? false
            if !playing && attemptsLeft > 1 { self.resumeMusic(m, attemptsLeft: attemptsLeft - 1); return }
            self.setState(m, playing: playing)
            self.report(playing ? L.switched(m.displayName) : L.startFailed(m.displayName))
        }
    }

    /// Uygulamayı öne getirmeden açar; AppleScript yanıt verene kadar (en çok ~10 sn) bekler.
    static func launchInBackground(_ a: AppAdapter, done: @escaping (Bool) -> Void) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: a.bundlePrefixes[0]) else { done(false); return }
        let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = false
        Log.write("[router] \(a.displayName) açılıyor")
        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, err in
            guard err == nil else { Log.write("[router] açılamadı: \(err!)"); done(false); return }
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<20 {
                    if a.isRunning, a.isPlaying() != nil { done(true); return }
                    Thread.sleep(forTimeInterval: 0.5)
                }
                done(false)
            }
        }
    }

    // MARK: - Kalıcı kaynak hafızası
    /// Yeniden başlatmada widget listesi kaybolmasın (Yasin, 2026-09-13): hafıza penceresi dolmamış ve hâlâ açık olan
    /// uygulamalar "Duraklatıldı" olarak geri gelir; hedef korunur. Böylece açılıştan sonraki ilk basış, macOS'un
    /// hatırladığı uygulamaya değil, en son kullandığın uygulamaya gider.
    private struct Remembered: Codable { let name: String; let lastActivity: Date; let isTarget: Bool }

    private func persistSources() {
        guard let memory else { return }
        let list = sources.filter { $0.kind == .controlled }
            .map { Remembered(name: $0.adapter.displayName, lastActivity: $0.lastActivity, isTarget: $0.isTarget) }
        memory.set(try? JSONEncoder().encode(list), forKey: Self.memoryKey)
    }

    private func restoreSources() {
        guard let memory, let data = memory.data(forKey: Self.memoryKey),
              let list = try? JSONDecoder().decode([Remembered].self, from: data) else { return }
        let now = Date()
        for r in list where now.timeIntervalSince(r.lastActivity) <= Settings.sourceMemory {
            guard let a = adapters.first(where: { $0.displayName == r.name }), let run = findRunning(a) else { continue }
            sources.append(SourceState(adapter: a, pid: run.pid, name: a.displayName, icon: run.icon,
                                       isPlaying: false, isTarget: r.isTarget, lastActivity: r.lastActivity))
        }
        target = sources.first(where: { $0.isTarget })?.adapter
        guard !sources.isEmpty else { return }
        Log.write("[router] hafızadan geri yüklendi: " + sources.map { $0.adapter.displayName + ($0.isTarget ? "*" : "") }.joined(separator: ", "))
        let mapped = mappedSources(), st = state
        DispatchQueue.main.async { st.sources = mapped }
    }

    private func mappedSources() -> [AppState.Source] {
        sources.map { AppState.Source(id: $0.adapter.displayName + ($0.kind == .unknown ? "#\($0.pid)" : ""), name: $0.name, icon: $0.icon, isPlaying: $0.isPlaying, isTarget: $0.isTarget, kind: $0.kind, pulse: $0.pulse) }
    }
    /// Bir sonraki "sürdür" basışının gideceği hedef.
    private(set) var target: AppAdapter?
    private(set) var lastEvent = "—"
    /// Son basıştaki kaynaklar; widget bunu gösterir.
    private(set) var sources: [SourceState] = []
    private var hint: String? = nil
    let state = AppState.shared
    var onChange: (() -> Void)?
    /// Router'ın tek iş parçacığı: tuş kararı, AppleScript, kaynak listesi hep burada. Ana iş parçacığı yalnız arayüz.
    let queue = DispatchQueue(label: "smartpause.router", qos: .userInteractive)

    /// Çift kaynak modu: ilk basıştan sonra bu süre içinde ikinci basış "ikinci basış" sayılır.
    var multiSourceWindow: TimeInterval = 1.5
    private var lastPressAt: Date = .distantPast
    private var burstActive = false

    private func adapter(for p: AudioProcess) -> AppAdapter? {
        adapters.first { $0.matches(bundleID: p.responsibleBundleID) || $0.matches(bundleID: p.bundleID) }
    }
    private func index(of a: AppAdapter) -> Int? { sources.firstIndex { $0.adapter.displayName == a.displayName } }

    // MARK: - Arka planda ses aktivitesi takibi (Space/tıklama ile durdurulma)
    func handleAudioActivity(pid: pid_t, isRunning: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            let rbundle = self.bundleIDForPID(pid)
            guard let a = self.adapters.first(where: { $0.matches(bundleID: rbundle) }) else { return }
            Log.write("[router] dış ses aktivitesi: \(a.displayName) isRunning=\(isRunning)")

            if isRunning {
                if let i = self.index(of: a) {
                    self.sources[i].isPlaying = true
                    self.sources[i].lastActivity = Date()
                } else {
                    let run = self.findRunning(a)
                    self.sources.append(SourceState(adapter: a, pid: run?.pid ?? pid, name: a.displayName,
                                                   icon: run?.icon, isPlaying: true, isTarget: false, lastActivity: Date()))
                }
                if self.target == nil || !self.sources.contains(where: { $0.adapter.displayName == self.target?.displayName && $0.isPlaying }) {
                    self.markTarget(a, reorder: false)
                }
                self.report(self.lastEvent, showHUD: false)
            } else {
                // Kaynak ses vermeyi kesti (space tuşu, mouse tıklaması veya sayfa içi butonla durduruldu)
                // "sanki kendisi durdurmuş gibi görsün"
                if let i = self.index(of: a) {
                    self.sources[i].isPlaying = false
                    self.sources[i].lastActivity = Date()
                    self.sources[i].pulse = true
                } else {
                    let run = self.findRunning(a)
                    self.sources.append(SourceState(adapter: a, pid: run?.pid ?? pid, name: a.displayName,
                                                   icon: run?.icon, isPlaying: false, isTarget: true, lastActivity: Date()))
                }
                self.markTarget(a, reorder: false)
                self.report(L.pausedX(a.displayName), showHUD: false)
            }
        }
    }

    /// Çalan kaynak yoksa, açık ve duraklatılmış medyası (video/audio) olan adapter'ı bulur.
    private func discoverPausedSource() -> SourceState? {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let front, let a = adapters.first(where: { $0.matches(bundleID: NSRunningApplication(processIdentifier: front)?.bundleIdentifier ?? "") }),
           a.isRunning && a.isControllable() && a.hasPausedMedia() {
            let icon = NSRunningApplication(processIdentifier: front)?.icon
            return SourceState(adapter: a, pid: front, name: a.displayName, icon: icon, isPlaying: false, isTarget: true, lastActivity: Date())
        }
        for a in adapters where a.isRunning && a.isControllable() {
            if a.hasPausedMedia() {
                let run = findRunning(a)
                return SourceState(adapter: a, pid: run?.pid ?? 0, name: a.displayName, icon: run?.icon, isPlaying: false, isTarget: true, lastActivity: Date())
            }
        }
        return nil
    }

    /// Ses çıkaran + adapter'lı kaynaklar (çalanlar ve duraklatılmış olanlar ayrılır).
    private func rankedSources(_ playing: [AudioProcess], excluding: [AppAdapter]) -> (active: [SourceState], paused: [SourceState]) {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var seen = Set<String>(excluding.map(\.displayName))   // Core Audio bayat kaydı: az önce durdurduklarımız aday değil
        var activeList: [(AudioProcess, AppAdapter)] = []
        var pausedList: [(AudioProcess, AppAdapter)] = []
        for p in playing {
            guard let a = adapter(for: p), !seen.contains(a.displayName) else { continue }
            seen.insert(a.displayName)
            let ip = a.isPlaying()
            Log.write("[rank] \(a.displayName) isPlaying=\(ip.map { "\($0)" } ?? "nil")")
            if ip == false {
                pausedList.append((p, a))
            } else {
                activeList.append((p, a))
            }
        }
        let sortFn: ((AudioProcess, AppAdapter), (AudioProcess, AppAdapter)) -> Bool = { l, r in
            let lf = l.0.responsiblePID == front, rf = r.0.responsiblePID == front
            if lf != rf { return lf }
            // 2) En son öne getirilen (kullanıcı niyeti), 3) en son ses çıkarmaya başlayan.
            let la = ActivationTracker.shared.lastActivation(pid: l.0.responsiblePID) ?? .distantPast
            let ra = ActivationTracker.shared.lastActivation(pid: r.0.responsiblePID) ?? .distantPast
            if la != ra { return la > ra }
            let lt = AudioActivityTracker.shared.startTime(pid: l.0.pid) ?? .distantPast
            let rt = AudioActivityTracker.shared.startTime(pid: r.0.pid) ?? .distantPast
            return lt > rt
        }
        let active = activeList.sorted(by: sortFn).map { p, a in
            SourceState(adapter: a, pid: p.responsiblePID, name: a.displayName,
                        icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: true, isTarget: false)
        }
        let paused = pausedList.sorted(by: sortFn).map { p, a in
            SourceState(adapter: a, pid: p.responsiblePID, name: a.displayName,
                        icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: false, isTarget: false)
        }
        return (active, paused)
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
        let playing = detect()
        AudioActivityTracker.shared.observe(playing: Set(playing.map(\.pid)))
        let (ranked, paused) = rankedSources(playing, excluding: [])
        mergeSources(ranked, paused: paused)
        if sources.isEmpty {
            if let discovered = discoverPausedSource() {
                sources.append(discovered)
                markTarget(discovered.adapter, reorder: false)
            } else {
                if let p = playing.first(where: { adapter(for: $0) == nil }) { report(L.unknownPassthrough(p.name)); return false }
                passthroughThenWatch(); return false
            }
        }
        if target == nil || index(of: target!) == nil { markTarget(ranked.first?.adapter ?? sources[0].adapter, reorder: false) }

        if let p = pendingPress {           // ikinci basış → çift basış: seçileni başlat/durdur
            p.cancel(); pendingPress = nil
            if let t = target {
                if let m = eligibleMusicApp() { playMusicApp(m, from: t) }
                else if let i = index(of: t), sources[i].isPlaying { performPause(t, keepTarget: t) } else { performResume(t) }
            }
            return true
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingPress = nil
            self.singlePressSwitch()
        }
        pendingPress = work
        queue.asyncAfter(deadline: .now() + Self.doublePressWindow, execute: work)
        return true
    }

    /// Tek basış: tek uygulama → başlat/durdur; birden çok → sıradakine geç (çalan durur, sıradaki başlar).
    private func singlePressSwitch() {
        guard let t = target, let ti = index(of: t) else { return }
                if sources.count == 1 {
            if sources[ti].isPlaying { performPause(t, keepTarget: t) } else { performResume(t) }
            return
        }
        let next = sources[(ti + 1) % sources.count].adapter
        performSwitch(from: t, to: next)
    }

    // MARK: - Mod 2/3: klasik (basış durdurur; hızlı ikinci basış geçirir ya da susturur)
    private func handleClassic() -> Bool {
        let playing = detect()
        AudioActivityTracker.shared.observe(playing: Set(playing.map(\.pid)))
        Log.write("[router] çalanlar: " + playing.map { "\($0.name)<\($0.responsibleBundleID)>" }.joined(separator: ", "))
        let secondPress = burstActive && Date().timeIntervalSince(lastPressAt) < multiSourceWindow
        lastPressAt = Date()

        if secondPress, let t = target {
            if Settings.multiSourceMode == .silenceAll {
                let playingOthers = sources.filter { $0.isPlaying && $0.adapter.displayName != t.displayName }
                if let next = playingOthers.first {
                    performPause(next.adapter, keepTarget: t)
                    return true
                }
                burstActive = false
                performResume(t)
                return true
            }

            // Settings.multiSourceMode == .switchTarget
            let controlled = sources.filter { $0.kind == .controlled }
            if controlled.count > 1, let ci = controlled.firstIndex(where: { $0.adapter.displayName == t.displayName }) {
                let next = controlled[(ci + 1) % controlled.count]
                burstActive = true
                if next.isPlaying {
                    performSwitch(from: next.adapter, to: t)
                } else {
                    performSwitch(from: t, to: next.adapter)
                }
                return true
            } else if let next = controlled.first(where: { $0.adapter.displayName != t.displayName }) {
                burstActive = true
                if next.isPlaying {
                    performSwitch(from: next.adapter, to: t)
                } else {
                    performSwitch(from: t, to: next.adapter)
                }
                return true
            } else if let m = eligibleMusicApp() {
                burstActive = true
                playMusicApp(m, from: t)
                return true
            }

            burstActive = false
            performResume(t)
            return true
        }

        let (ranked, paused) = rankedSources(playing, excluding: [])
        mergeSources(ranked, paused: paused)
        if let primary = ranked.first {
            if !primary.adapter.isControllable() { report(L.notControllable(primary.name)); return false }
            burstActive = true
            performPause(primary.adapter, keepTarget: nil)
            return true
        }
        burstActive = false
        if let p = playing.first(where: { adapter(for: $0) == nil }), target == nil {
            sources = sources.filter { $0.kind != .unknown } + [SourceState(adapter: ScriptableAdapter.spotify, pid: p.responsiblePID, name: p.name,
                                   icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: true, isTarget: false, kind: .unknown)]
            hint = L.requestSupportHint.t
            report(L.unknownPassthrough(p.name))
            return false
        }
        if target == nil, let discovered = discoverPausedSource() {
            sources.append(discovered)
            markTarget(discovered.adapter, reorder: false)
        }
        if let t = target {
            burstActive = true
            performResume(t)
            return true
        }
        passthroughThenWatch()
        return false
    }

    /// Ses yok, hafıza boş: tuş macOS'a bırakılır. macOS kendi "Now Playing" uygulamasını başlatabilir (Spotify, Brave...);
    /// hangisini başlattığını önceden bilemeyiz (MediaRemote özel API, 15.4+ kilitli). Bunun yerine kısa bir süre sonra
    /// yeniden bakılır: bir uygulama ses vermeye başladıysa widget'ta gösterilir ve hafızaya alınır (Yasin, 2026-09-12).
    static let systemStartWatchDelay: TimeInterval = 0.7
    private func passthroughThenWatch() {
        report(L.noAudio.t)
        queue.asyncAfter(deadline: .now() + Self.systemStartWatchDelay) { [weak self] in
            guard let self, self.sources.isEmpty else { return }
            let playing = self.detect()
            guard !playing.isEmpty else { return }
            AudioActivityTracker.shared.observe(playing: Set(playing.map(\.pid)))
            let (ranked, paused) = self.rankedSources(playing, excluding: [])
            self.mergeSources(ranked, paused: paused)
            if let primary = ranked.first {
                self.markTarget(primary.adapter, reorder: false)
                self.report(L.systemStarted(primary.name))
            } else if let p = playing.first {
                self.sources = [SourceState(adapter: ScriptableAdapter.spotify, pid: p.responsiblePID, name: p.name,
                                            icon: NSRunningApplication(processIdentifier: p.responsiblePID)?.icon, isPlaying: true, isTarget: false, kind: .unknown)]
                self.hint = L.requestSupportHint.t
                self.report(L.systemStarted(p.name))
            }
        }
    }

    /// Arayüzden (ana iş parçacığı) çağrılır; iş router kuyruğuna aktarılır.
    func userSelect(named n: String) { queue.async { if let a = self.adapters.first(where: { $0.displayName == n }) { self.userSelect(a) } } }
    func userToggle(named n: String) { queue.async { if let a = self.adapters.first(where: { $0.displayName == n }) { self.userToggle(a) } } }

    /// Kaynak listesi kalıcıdır (Yasin kararı, 2026-09-10): bir kez görülen uygulama, kapanana kadar widget'ta kalır;
    /// duraklatılmış olsa da çift tıkla sürdürülebilir. Yeni çalanlar eklenir, çalmayanlar "Duraklatıldı" olur.
    /// Hafıza penceresi (Yasin, 2026-09-10): son 4 dakikada medya oynatan kaynak widget'ta kalır.
    private func mergeSources(_ ranked: [SourceState], paused: [SourceState] = []) {
        for r in ranked {
            if let i = index(of: r.adapter) { sources[i].isPlaying = true; sources[i].lastActivity = Date() }
            else { sources.append(r) }
        }
        for p in paused {
            if let i = index(of: p.adapter) {
                sources[i].isPlaying = false
                sources[i].lastActivity = Date()
            } else {
                sources.append(p)
            }
        }
        let playingNames = Set(ranked.map { $0.adapter.displayName })
        for i in sources.indices where !playingNames.contains(sources[i].adapter.displayName) {
            sources[i].isPlaying = false
        }
        // Uygulama kapandıysa listeden düşür.
        sources.removeAll {
            $0.kind == .unknown || !isAlive($0)
            || (!$0.isPlaying && Date().timeIntervalSince($0.lastActivity) > Settings.sourceMemory)
        }
        if let t = target, index(of: t) == nil { target = nil }
    }

    /// Widget'tan tek tık: bu kaynağı HEDEF yap (çalma durumu değişmez; bir sonraki tuş onu etkiler).
    func userSelect(_ a: AppAdapter) {
        guard index(of: a) != nil else { return }
        markTarget(a)
        burstActive = false
        report(L.targetIs(a.displayName))
    }
    /// Widget'tan: bu kaynağı başlat/durdur.
    func userToggle(_ a: AppAdapter) {
        guard let i = index(of: a) else { return }
                if sources[i].isPlaying { performPause(a, keepTarget: a) } else { performResume(a) }
    }

    /// Next/prev: ses çıkaran ve adapter'ı destekleyen uygulamaya gönderilir; yoksa passthrough.
    func handleTrackChange(forward: Bool) -> Bool {
        let playing = detect()
        let (active, _) = rankedSources(playing, excluding: [])
        for s in active {
            let ok = forward ? s.adapter.next() : s.adapter.previous()
            report(ok ? (forward ? L.nextTrack(s.name) : L.prevTrack(s.name)) : L.trackFailed(s.name))
            return true
        }
        report(L.trackPassthrough.t); return false
    }

    // MARK: - Eylemler (ana kuyruk)

    private func setState(_ a: AppAdapter, playing: Bool) {
        if let i = index(of: a) { sources[i].isPlaying = playing; sources[i].lastActivity = Date() }
    }
    /// Sözleşme (Yasin, 2026-09-11): vurgu HEP ilk satırda sabittir; hedef değişince satırlar yer değiştirir
    /// (hedef üste çıkar, üstteki aşağı iner). Çift tıkın ikinci tıkı ilk tıktaki uygulamaya gider (HUDPanel `pending`),
    /// bu yüzden tıklamada da yeniden sıralamak güvenlidir.
    private func markTarget(_ a: AppAdapter?, reorder: Bool = true) {
        target = a
        for i in sources.indices { sources[i].isTarget = a.map { $0.displayName == sources[i].adapter.displayName } ?? false }
        if reorder, let i = sources.firstIndex(where: { $0.isTarget }), i != 0 { sources.insert(sources.remove(at: i), at: 0) }
    }

    private func performPause(_ a: AppAdapter, keepTarget: AppAdapter?) {
        if a.pause() {
            setState(a, playing: false)
            if let i = index(of: a) { sources[i].pulse = true }
            markTarget(keepTarget ?? a)
            report(keepTarget == nil ? L.pausedX(a.displayName) : L.alsoPaused(a.displayName))
            return
        }
        // Durdurulacak bir şey yoktu (tarayıcıda çalan media kalmamış) → sürdürme dene.
        setState(a, playing: false)
        if let t = target { performResume(t) } else { report(L.pauseFailed(a.displayName)) }
    }
    private func performResume(_ a: AppAdapter) {
        let ok = a.resume()
        if ok { setState(a, playing: true) }
        markTarget(a)
        report(ok ? L.resumed(a.displayName) : L.resumeFailed(a.displayName))
    }
    /// Kaynak geçişi: mevcut hedef çalıyorsa durur, sıradaki başlar, seçim ona geçer.
    private func performSwitch(from old: AppAdapter, to new: AppAdapter) {
        if let i = index(of: old), sources[i].isPlaying, old.pause() {
            setState(old, playing: false)
            sources[i].pulse = true
        }
        let alreadyPlaying = index(of: new).map { sources[$0].isPlaying } ?? false
        let ok = alreadyPlaying || new.resume()
        if ok { setState(new, playing: true) }
        markTarget(new)
        report(ok ? L.switched(new.displayName) : L.startFailed(new.displayName))
    }
    private func report(_ s: String, showHUD: Bool = true) {
        lastEvent = s; Log.write("[router] \(s)")
        // İpucu: iki kaynak varsa ikinci basışın ne yapacağını söyle.
        if Settings.multiSourceMode == .switchKey, sources.count > 1, let t = target, let ti = index(of: t) {
            let next = sources[(ti + 1) % sources.count]
            hint = L.switchHint(next.name, t.displayName)
        } else if sources.count > 1, let t = target {
            if Settings.multiSourceMode == .switchTarget,
               let other = sources.first(where: { $0.adapter.displayName != t.displayName && $0.kind == .controlled }) {
                hint = L.againSwitch(other.name)
            } else if Settings.multiSourceMode == .silenceAll,
                      let other = sources.first(where: { $0.adapter.displayName != t.displayName && $0.isPlaying }) {
                hint = L.againSilence(other.name)
            } else if !sources.contains(where: { $0.kind == .unknown }) { hint = nil }
        } else if let t = target, let m = eligibleMusicApp() {
            hint = L.singleSourceHint(t.displayName, m.displayName)
        } else if !sources.contains(where: { $0.kind == .unknown }) { hint = nil }
        let mapped = mappedSources()
        for i in sources.indices { sources[i].pulse = false }
        persistSources()
        let st = state
        DispatchQueue.main.async {
            st.sources = mapped; st.headline = s; st.hint = self.hint; st.lastEventAt = Date(); st.hudRevision += 1
            if showHUD { self.onChange?() }
        }
    }
}
