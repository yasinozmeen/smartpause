import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let state = AppState.shared
    private let router = Router()
    private let blocker = MusicBlocker()
    private var tap: MediaKeyTap!
    private var hud: HUDPanel!
    private var retryTimer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        Log.write("[app] başladı, sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?"), erişilebilirlik=\(MediaKeyTap.isTrusted)")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "playpause.circle.fill", accessibilityDescription: "SmartPause")
            b.target = self; b.action = #selector(statusClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        blocker.enabled = state.blockMusic
        AudioActivityTracker.shared.start()
        ActivationTracker.shared.start()

        hud = HUDPanel(state: state,
                       onSelect: { [weak self] s in self?.router.userSelect(named: s.id) },
                       onToggle: { [weak self] s in self?.router.userToggle(named: s.id) },
                       onHelp: { [weak self] in self?.openHelp() })
        router.onChange = { [weak self] in
            guard let self, self.state.showHUD else { return }
            self.hud.present()
        }
        tap = MediaKeyTap { [weak self] keyCode in
            guard let self, self.state.enabled else { return false }
            switch keyCode {
            case MediaKeyTap.NX_KEYTYPE_PLAY: return self.router.handlePlayPause()
            case MediaKeyTap.NX_KEYTYPE_NEXT, MediaKeyTap.NX_KEYTYPE_FAST: return self.router.handleTrackChange(forward: true)
            case MediaKeyTap.NX_KEYTYPE_PREVIOUS, MediaKeyTap.NX_KEYTYPE_REWIND: return self.router.handleTrackChange(forward: false)
            default: return false
            }
        }
        if !MediaKeyTap.isTrusted { MediaKeyTap.requestTrust() }
        startTapIfPossible()
        refreshIcon()
    }

    /// İzin sonradan verilirse uygulamayı yeniden başlatmadan tap kurulsun.
    private func startTapIfPossible() {
        state.trusted = MediaKeyTap.isTrusted
        if state.trusted, tap.start() { retryTimer?.invalidate(); retryTimer = nil; refreshIcon(); return }
        if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.startTapIfPossible() }
        }
    }

    private func refreshIcon() {
        statusItem.button?.image = NSImage(systemSymbolName: state.enabled && state.trusted ? "playpause.circle.fill" : "playpause.circle", accessibilityDescription: "SmartPause")
        statusItem.button?.appearsDisabled = !state.trusted || !state.enabled
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            // Panel (bir sonraki adım): şimdilik yardım
            openHelp()
        } else {
            if state.trusted, state.sources.isEmpty { state.headline = "Tuşu bekliyorum" }
            hud.present()
        }
    }

    func openHelp() {
        if !state.trusted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/yasinozmeen/smartpause/issues/new?title=Uygulama%20deste%C4%9Fi")!)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
