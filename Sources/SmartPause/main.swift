import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let router = Router()
    private let blocker = MusicBlocker()
    private var tap: MediaKeyTap!
    private var enabled = true
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enableItem = NSMenuItem(title: "SmartPause etkin", action: #selector(toggleEnabled), keyEquivalent: "")
    private let blockItem = NSMenuItem(title: "Apple Music'in açılmasını engelle", action: #selector(toggleBlock), keyEquivalent: "")

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "playpause.circle", accessibilityDescription: "SmartPause")
        buildMenu()
        blocker.enabled = true; blockItem.state = .on
        router.onChange = { [weak self] in self?.refresh() }

        tap = MediaKeyTap { [weak self] keyCode in
            guard let self, self.enabled, keyCode == MediaKeyTap.NX_KEYTYPE_PLAY else { return false }
            return self.router.handlePlayPause()
        }
        if !MediaKeyTap.isTrusted { MediaKeyTap.requestTrust() }
        if !tap.start() {
            statusLine.title = "Erişilebilirlik izni gerekli — verdikten sonra yeniden başlat"
        }
        refresh()
    }

    private func buildMenu() {
        let m = NSMenu()
        statusLine.isEnabled = false
        m.addItem(statusLine)
        m.addItem(.separator())
        enableItem.target = self; m.addItem(enableItem)
        blockItem.target = self; m.addItem(blockItem)
        m.addItem(.separator())
        let adaptersTitle = NSMenuItem(title: "Adapter'lar", action: nil, keyEquivalent: ""); adaptersTitle.isEnabled = false
        m.addItem(adaptersTitle)
        for a in router.adapters {
            let i = NSMenuItem(title: "   \(a.displayName)", action: nil, keyEquivalent: ""); i.isEnabled = false; m.addItem(i)
        }
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = m
    }

    private func refresh() {
        enableItem.state = enabled ? .on : .off
        let playing = AudioDetector.runningOutputProcesses().map(\.name)
        let now = playing.isEmpty ? "Şu an ses çıkaran uygulama yok" : "Ses çıkaran: \(playing.joined(separator: ", "))"
        if MediaKeyTap.isTrusted { statusLine.title = "\(now)\nSon: \(router.lastEvent)" }
        statusItem.button?.image = NSImage(systemSymbolName: enabled ? "playpause.circle.fill" : "playpause.circle", accessibilityDescription: "SmartPause")
    }

    @objc private func toggleEnabled() { enabled.toggle(); refresh() }
    @objc private func toggleBlock() { blocker.enabled.toggle(); blockItem.state = blocker.enabled ? .on : .off }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
