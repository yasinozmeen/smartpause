import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let router = Router()
    private let blocker = MusicBlocker()
    private var tap: MediaKeyTap!
    private var enabled = true
    private let menu = NSMenu()
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "", action: #selector(openAccessibility), keyEquivalent: "")
    private let enableItem = NSMenuItem(title: "SmartPause etkin", action: #selector(toggleEnabled), keyEquivalent: "")
    private let blockItem = NSMenuItem(title: "Apple Music'in kendiliğinden açılmasını engelle", action: #selector(toggleBlock), keyEquivalent: "")
    private var adapterItems: [(NSMenuItem, AppAdapter)] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        blocker.enabled = true; blockItem.state = .on
        router.onChange = { [weak self] in self?.refresh() }
        tap = MediaKeyTap { [weak self] keyCode in
            guard let self, self.enabled, keyCode == MediaKeyTap.NX_KEYTYPE_PLAY else { return false }
            return self.router.handlePlayPause()
        }
        if !MediaKeyTap.isTrusted { MediaKeyTap.requestTrust() }
        startTapIfPossible()
        refresh()
    }

    /// İzin sonradan verilirse uygulamayı yeniden başlatmadan tap kurulsun.
    private var retryTimer: Timer?
    private func startTapIfPossible() {
        if MediaKeyTap.isTrusted, tap.start() { retryTimer?.invalidate(); retryTimer = nil; return }
        if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.startTapIfPossible(); self?.refresh() }
        }
    }

    private func buildMenu() {
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        permissionItem.target = self; menu.addItem(permissionItem)
        menu.addItem(.separator())
        enableItem.target = self; menu.addItem(enableItem)
        blockItem.target = self; menu.addItem(blockItem)
        menu.addItem(.separator())
        let t = NSMenuItem(title: "Adapter'lar", action: nil, keyEquivalent: ""); t.isEnabled = false; menu.addItem(t)
        for a in router.adapters {
            let i = NSMenuItem(title: a.displayName, action: nil, keyEquivalent: ""); i.isEnabled = false
            menu.addItem(i); adapterItems.append((i, a))
        }
        menu.addItem(.separator())
        let help = NSMenuItem(title: "Kurulum yardımı…", action: #selector(showHelp), keyEquivalent: ""); help.target = self; menu.addItem(help)
        menu.addItem(NSMenuItem(title: "Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        for (item, a) in adapterItems {
            let r = a.readiness()
            item.title = "\(r.symbol)  \(a.displayName)" + (r.note.map { "  —  \($0)" } ?? "")
        }
    }

    private func refresh() {
        enableItem.state = enabled ? .on : .off
        let trusted = MediaKeyTap.isTrusted
        permissionItem.isHidden = trusted
        permissionItem.title = "⚠︎ Erişilebilirlik izni gerekli — ayarları aç…"
        let playing = AudioDetector.runningOutputProcesses().map(\.name)
        let now = playing.isEmpty ? "Şu an ses çıkaran uygulama yok" : "Ses çıkaran: \(playing.joined(separator: ", "))"
        statusLine.title = "\(now)\nSon: \(router.lastEvent)"
        let symbol = !trusted ? "playpause.circle" : (enabled ? "playpause.circle.fill" : "playpause.circle")
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "SmartPause")
        statusItem.button?.appearsDisabled = !trusted || !enabled
    }

    @objc private func toggleEnabled() { enabled.toggle(); refresh() }
    @objc private func toggleBlock() { blocker.enabled.toggle(); blockItem.state = blocker.enabled ? .on : .off }
    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func showHelp() {
        let a = NSAlert()
        a.messageText = "SmartPause kurulumu"
        a.informativeText = """
        1. Erişilebilirlik izni (zorunlu): Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik › SmartPause'u ekle. Tuşu yakalamak için gerekir.

        2. Otomasyon izni: İlk basışta macOS "SmartPause, Spotify'ı denetlemek istiyor" diye sorar; İzin Ver'i seç. Her uygulama için bir kez sorulur.

        3. Tarayıcılar: Chrome/Brave/Arc'ta Görünüm › Geliştirici › "Apple Events'ten JavaScript'e izin ver"; Safari'de Geliştir menüsünde aynı seçenek. Bu olmadan tarayıcıdaki video durdurulamaz, tuş sisteme bırakılır.

        Adapter listesindeki ✓ / ⚠︎ işaretleri hangi adımın eksik olduğunu gösterir.
        """
        a.addButton(withTitle: "Erişilebilirlik ayarlarını aç")
        a.addButton(withTitle: "Kapat")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn { openAccessibility() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
