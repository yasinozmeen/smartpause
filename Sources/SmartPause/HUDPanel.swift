import AppKit

/// Menü barının hemen altında beliren küçük widget: hangi kaynaklar çalıyor, hedef hangisi.
/// Tek tık → hedefi o uygulamaya geçir. Çift tık → o uygulamayı başlat/durdur. (Deneysel; kullanıcı testine göre değişecek.)
final class HUDPanel: NSPanel {
    private let effect = NSVisualEffectView()
    private let stack = NSStackView()
    private var hideTimer: Timer?
    private var tracking: NSTrackingArea?
    var onSelect: ((AppAdapter) -> Void)?
    var onToggle: ((AppAdapter) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
        alphaValue = 0

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        contentView = effect

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
    }

    func show(sources: [SourceState], event: String, below statusButton: NSStatusBarButton?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let title = NSTextField(labelWithString: event)
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingTail
        stack.addArrangedSubview(title)
        stack.setCustomSpacing(6, after: title)
        for s in sources { stack.addArrangedSubview(SourceRow(state: s, onSelect: onSelect, onToggle: onToggle)) }
        stack.arrangedSubviews.forEach { v in
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
        }
        layoutIfNeeded()
        let size = stack.fittingSize
        let w = max(260, size.width), h = size.height
        // Menü barının hemen altı, sağ üst köşe. (Simge penceresinin konumu macOS 26'da güvenilir değil: ölçüldü, x=-4200.)
        // Fare hangi ekrandaysa o ekran; yoksa ana ekran.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let origin = NSPoint(x: vf.maxX - w - 12, y: vf.maxY - h - 8)
        setFrame(NSRect(origin: origin, size: NSSize(width: w, height: h)), display: true)
        Log.write("[hud] göster \(sources.count) kaynak, çerçeve \(frame)")
        if let t = tracking { effect.removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: effect.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        effect.addTrackingArea(tracking!)

        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.16; animator().alphaValue = 1 }
        scheduleHide(after: 2.6)
    }

    private func scheduleHide(after s: TimeInterval) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: s, repeats: false) { [weak self] _ in self?.hide() }
    }
    func hide() {
        hideTimer?.invalidate()
        NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.22; animator().alphaValue = 0 }) { [weak self] in
            if self?.alphaValue == 0 { self?.orderOut(nil) }
        }
    }
    override func mouseEntered(with event: NSEvent) { hideTimer?.invalidate() }
    override func mouseExited(with event: NSEvent) { scheduleHide(after: 1.2) }
}

/// Bir kaynak satırı: simge, ad, durum, hedef işareti.
final class SourceRow: NSView {
    private let state: SourceState
    private let onSelect: ((AppAdapter) -> Void)?
    private let onToggle: ((AppAdapter) -> Void)?

    init(state: SourceState, onSelect: ((AppAdapter) -> Void)?, onToggle: ((AppAdapter) -> Void)?) {
        self.state = state; self.onSelect = onSelect; self.onToggle = onToggle
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        if state.isTarget { layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor }

        let icon = NSImageView(image: state.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let name = NSTextField(labelWithString: state.name)
        name.font = .systemFont(ofSize: 13, weight: state.isTarget ? .semibold : .regular)

        let status = NSTextField(labelWithString: state.isPlaying ? "Çalıyor" : "Duraklatıldı")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor

        let text = NSStackView(views: [name, status])
        text.orientation = .vertical; text.alignment = .leading; text.spacing = 0

        let mark = NSImageView(image: NSImage(systemSymbolName: state.isPlaying ? "speaker.wave.2.fill" : "pause.fill", accessibilityDescription: nil)!)
        mark.contentTintColor = state.isTarget ? .controlAccentColor : .tertiaryLabelColor
        mark.symbolConfiguration = .init(pointSize: 12, weight: .semibold)

        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let target = NSTextField(labelWithString: state.isTarget ? "hedef" : "")
        target.font = .systemFont(ofSize: 10, weight: .medium); target.textColor = .controlAccentColor

        let row = NSStackView(views: [icon, text, spacer, target, mark])
        row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 10)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor), row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        toolTip = "Tek tık: hedef yap · Çift tık: başlat/durdur"
    }
    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onToggle?(state.adapter) } else if event.clickCount == 1 { onSelect?(state.adapter) }
    }
}
