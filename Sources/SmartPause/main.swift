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
    private var panel: SettingsPanel!
    private var onboarding: OnboardingWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        Log.write("[app] başladı, sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?"), erişilebilirlik=\(MediaKeyTap.isTrusted)")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.target = self; b.action = #selector(statusClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        blocker.enabled = state.blockMusic
        panel = SettingsPanel(state: state, content: PanelView(
            state: state, adapters: router.adapters,
            onQuit: { NSApp.terminate(nil) },
            onHelp: { [weak self] in self?.openHelp() },
            onSetting: { [weak self] a in self?.showSetting(for: a) },
            onChanged: { [weak self] in self?.settingsChanged() },
            onOnboarding: { [weak self] in self?.panel.dismiss(); self?.showOnboarding() }))
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
        installDebugSignals()
        if !Settings.onboardingDone || !state.trusted { showOnboarding() }
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
        let ic = state.menuBarIcon
        statusItem.button?.image = NSImage(systemSymbolName: state.enabled && state.trusted ? ic.rawValue : ic.dimmed, accessibilityDescription: "SmartPause")
        statusItem.button?.appearsDisabled = !state.trusted || !state.enabled
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            togglePanel(sender, anchorX: NSEvent.mouseLocation.x)
        } else {
            if state.trusted, state.sources.isEmpty { state.headline = "Tuşu bekliyorum" }
            hud.present()
        }
    }

    private func settingsChanged() {
        blocker.enabled = state.blockMusic
        refreshIcon()
    }
    private func showSetting(for a: AppAdapter) {
        let hint = (a as? ChromiumAdapter).map { _ in ChromiumAdapter.settingHint } ?? SafariAdapter.settingHint
        let al = NSAlert(); al.messageText = "\(a.displayName) için tek ayar"; al.informativeText = hint + "\n\nBu ayar olmadan da çalışır: tuşu sisteme bırakırım."
        al.addButton(withTitle: "Tamam"); NSApp.activate(ignoringOtherApps: true); al.runModal()
    }

    /// Geliştirme kancası: `kill -USR1 <pid>` paneli, `kill -USR2 <pid>` widget'ı açar (ekran görüntüsü testleri için).
    private var sigSources: [DispatchSourceSignal] = []
    private func installDebugSignals() {
        for (sig, kind) in [(SIGUSR1, 0), (SIGUSR2, 1), (SIGINFO, 2)] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in
                guard let self, let b = self.statusItem.button else { return }
                switch kind { case 0: self.togglePanel(b, anchorX: nil); case 1: self.hud.present(); default: self.showOnboarding() }
            }
            src.resume(); sigSources.append(src)
        }
    }
    private func togglePanel(_ sender: NSStatusBarButton, anchorX: CGFloat?) {
        if panel.isShown { panel.dismiss(); return }
        hud.dismiss()
        panel.present(anchorX: anchorX)
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindow(view: OnboardingView(state: state, adapters: router.adapters,
                onFinish: { [weak self] in Settings.onboardingDone = true; self?.onboarding?.close() },
                onShowSetting: { [weak self] a in self?.showSetting(for: a) }))
        }
        NSApp.activate(ignoringOtherApps: true)
        onboarding?.makeKeyAndOrderFront(nil)
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
