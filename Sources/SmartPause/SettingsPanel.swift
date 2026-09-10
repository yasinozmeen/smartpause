import AppKit
import SwiftUI

/// Sağ tık paneli: kendi cam penceremiz. Neden NSPopover değil: macOS 26 menü bar simgesinin konumunu
/// sahte veriyor (ölçüldü: x = -4200), popover köşeye düşüyor. Konum, tıklama anındaki fare x'inden alınır.
final class SettingsPanel: NSPanel {
    private let effect = NSVisualEffectView()
    private let arrow = ArrowView()
    private var hosting: NSHostingView<PanelView>!
    private var monitors: [Any] = []
    private let state: AppState
    private let arrowH: CGFloat = 8

    init(state: AppState, content: PanelView) {
        self.state = state
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        isOpaque = false; backgroundColor = .clear; hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        appearance = NSAppearance(named: .vibrantDark)
        alphaValue = 0

        let root = NSView()
        contentView = root
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 20
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        effect.translatesAutoresizingMaskIntoConstraints = false
        arrow.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(effect); root.addSubview(arrow)

        hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: root.leadingAnchor), effect.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            effect.topAnchor.constraint(equalTo: root.topAnchor, constant: arrowH), effect.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor), hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor), hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            arrow.topAnchor.constraint(equalTo: root.topAnchor), arrow.heightAnchor.constraint(equalToConstant: arrowH + 1),
            arrow.widthAnchor.constraint(equalToConstant: 18),
        ])
        arrowX = arrow.centerXAnchor.constraint(equalTo: root.leadingAnchor, constant: 180)
        arrowX.isActive = true
    }
    private var arrowX: NSLayoutConstraint!

    var isShown: Bool { isVisible && alphaValue > 0.5 }

    /// `anchorX`: ekran koordinatında simgenin x'i (fare); nil → sağ üst.
    func present(anchorX: CGFloat?) {
        let size = NSSize(width: hosting.fittingSize.width, height: hosting.fittingSize.height + arrowH)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let ax = anchorX ?? (vf.maxX - 30)
        var x = ax - size.width / 2
        x = min(max(x, vf.minX + 8), vf.maxX - size.width - 8)
        let target = NSRect(x: x, y: vf.maxY - size.height - 2, width: size.width, height: size.height)
        arrowX.constant = min(max(ax - x, 24), size.width - 24)
        let reduce = state.reduceMotion
        var start = target; if !reduce { start.origin.y += 8 }
        setFrame(start, display: true)
        alphaValue = 0
        orderFrontRegardless()
        makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduce ? 0.15 : 0.30
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            animator().alphaValue = 1; animator().setFrame(target, display: true)
        }
        installMonitors()
        Log.write("[panel] çerçeve \(target)")
    }

    func dismiss() {
        removeMonitors()
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = state.reduceMotion ? 0.12 : 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }) { [weak self] in if self?.alphaValue == 0 { self?.orderOut(nil) } }
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { dismiss() }

    private func installMonitors() {
        removeMonitors()
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.dismiss() } { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] e in
            if e.keyCode == 53 { self?.dismiss(); return nil }   // Esc
            return e
        } { monitors.append(m) }
    }
    private func removeMonitors() { monitors.forEach { NSEvent.removeMonitor($0) }; monitors.removeAll() }
}

/// Panelin üstündeki küçük ok.
final class ArrowView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 0, y: 0)); p.line(to: NSPoint(x: bounds.midX, y: bounds.height)); p.line(to: NSPoint(x: bounds.width, y: 0)); p.close()
        NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.19, alpha: 0.96).setFill(); p.fill()
        NSColor.white.withAlphaComponent(0.14).setStroke(); p.lineWidth = 1; p.stroke()
    }
}
