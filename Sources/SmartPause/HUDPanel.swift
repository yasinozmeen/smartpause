import AppKit
import SwiftUI

/// Menü barının hemen altında beliren widget. Giriş 380 ms yavaşlayarak, çıkış 220 ms hızlanarak.
/// Bekleme 2,6 sn; fare üstündeyken kalır. Azaltılmış hareket: 150 ms yalnız opaklık.
final class HUDPanel: NSPanel {
    private let effect = NSVisualEffectView()
    private var hosting: FirstMouseHostingView<HUDView>!
    private var hideTimer: Timer?
    private var tracking: NSTrackingArea?
    private let state: AppState
    private var restY: CGFloat = 0

    init(state: AppState, onSelect: @escaping (AppState.Source) -> Void, onToggle: @escaping (AppState.Source) -> Void, onHelp: @escaping () -> Void) {
        self.state = state
        super.init(contentRect: NSRect(x: 0, y: 0, width: 296, height: 80),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        alphaValue = 0
        appearance = NSAppearance(named: .vibrantDark)

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        contentView = effect

        hosting = FirstMouseHostingView(rootView: HUDView(state: state, onSelect: onSelect, onToggle: onToggle, onHelp: onHelp))
        var pending: AppState.Source? = nil   // çift tıkın ikinci tıkı, ilk tıktaki uygulamaya gider
        hosting.onRowClick = { [weak state] row, count in
            guard let state else { return }
            if !state.trusted { onHelp(); return }
            if count >= 2, let p = pending { onToggle(p); return }
            if row >= 0 && row < state.sources.count {
                let src = state.sources[row]
                if src.kind == .unknown { onHelp(); return }
                pending = src
                onSelect(src)
            } else if row >= state.sources.count, state.sources.contains(where: { $0.kind == .unknown }) { onHelp() }
        }
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor), hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor), hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
    }

    /// Göster (ya da zaten açıksa içeriği güncelle ve süreyi tazele).
    func present() {
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        restY = vf.maxY - size.height - 8
        let target = NSRect(x: vf.maxX - size.width - 12, y: restY, width: size.width, height: size.height)
        let reduce = state.reduceMotion
        let wasVisible = isVisible && alphaValue > 0.5

        if let t = tracking { effect.removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: NSRect(origin: .zero, size: size), options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        effect.addTrackingArea(tracking!)

        if wasVisible {
            NSAnimationContext.runAnimationGroup { ctx in ctx.duration = reduce ? 0.15 : 0.26; ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1); animator().setFrame(target, display: true) }
        } else {
            hideTimer?.invalidate()
            // Giriş (Yasin, 2026-09-11): ekranın sağ kenarından bir çekmece gibi kayarak gelir; çıkış yine sağa kayar.
            var start = target; if !reduce { start.origin.x = screen.frame.maxX + 12 }
            setFrame(start, display: true)
            alphaValue = reduce ? 0 : 0.85
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = reduce ? 0.15 : 0.44
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
                animator().alphaValue = 1
                animator().setFrame(target, display: true)
            }
        }
        scheduleHide(after: Settings.hudDuration)
        Log.write("[hud] çerçeve \(target)")
    }

    private func scheduleHide(after s: TimeInterval) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: s, repeats: false) { [weak self] _ in self?.dismiss() }
    }
    func dismiss() {
        hideTimer?.invalidate()
        guard isVisible else { return }
        let reduce = state.reduceMotion
        var end = frame
        if !reduce, let scr = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) { end.origin.x = scr.frame.maxX + 12 }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduce ? 0.15 : 0.30
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.9, 0.4)
            animator().alphaValue = reduce ? 0 : 0.7
            animator().setFrame(end, display: true)
        }) { [weak self] in guard let self, !(self.hideTimer?.isValid ?? false) else { return }; self.alphaValue = 0; self.orderOut(nil) }
    }
    /// Kayarak giriş/çıkış için pencerenin ekran dışına taşmasına izin ver (AppKit varsayılan olarak ekrana sıkıştırır).
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override func mouseEntered(with event: NSEvent) { hideTimer?.invalidate() }
    override func mouseExited(with event: NSEvent) { scheduleHide(after: min(1.2, Settings.hudDuration)) }
}

/// Etkinleştirmeyen panelde tıklamalar AppKit düzeyinde yakalanır (SwiftUI dokunma algılayıcıları bu pencerede tetiklenmiyor — ölçüldü).
/// Satır geometrisi HUDView ile aynı: üst boşluk 10, satır 46, aralık 2.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var onRowClick: ((_ row: Int, _ clickCount: Int) -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let fromTop = (isFlipped ? p.y : bounds.height - p.y) - 10
        let row = fromTop < 0 ? -1 : Int(fromTop / 48)
        onRowClick?(row, event.clickCount)
    }
}
