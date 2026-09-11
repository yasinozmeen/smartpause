import SwiftUI
import AppKit

/// Onboarding (onaylı tasarım): sol adım listesi, sağda tek ekran; 3 adım. İzin gelince kendiliğinden ilerler.
struct OnboardingView: View {
    @ObservedObject var state: AppState
    let adapters: [AppAdapter]
    var onFinish: () -> Void
    var onShowSetting: (AppAdapter) -> Void

    @State private var step = 1
    @State private var readiness: [String: Readiness] = [:]
    @State private var waitingPulse = false
    private var steps: [String] { [L.stepAccess.t, L.tabApps.t, L.stepTry.t] }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: 26, leading: 26, bottom: 22, trailing: 26))
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .frame(width: 640, height: 300)
        .animation(state.reduceMotion ? nil : .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.32), value: step)
        .onAppear { if state.trusted { step = 2 }; refreshReadiness() }
        .onChange(of: state.trusted) { _, t in if t && step == 1 { step = 2 } }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, name in
                let n = i + 1
                HStack(spacing: 10) {
                    ZStack {
                        if n < step {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.green)
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.black)
                        } else if n == step {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor)
                            Text("\(n)").font(.system(size: 12, weight: .bold))
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(.secondary, lineWidth: 1.5)
                            Text("\(n)").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }.frame(width: 22, height: 22)
                    Text(name).font(.system(size: 13, weight: n == step ? .semibold : .regular)).foregroundStyle(n > step ? .secondary : .primary)
                }
            }
            Spacer()
            Text(step == 1 ? L.step1of3.t : step == 2 ? L.step2of3.t : L.step3of3.t)
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(EdgeInsets(top: 22, leading: 18, bottom: 18, trailing: 18))
        .frame(width: 190, alignment: .topLeading)
        .background(Color.white.opacity(0.04))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(width: 1), alignment: .trailing)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 1: stepPermission
        case 2: stepApps
        default: stepTry
        }
    }

    private var stepPermission: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                title(L.obPermTitle.t)
                body_(L.obPermBody.t)
                Spacer()
                HStack(spacing: 12) {
                    Button(L.openSystemSettings.t) {
                        MediaKeyTap.requestTrust()
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    Text(L.continuesAuto.t).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.accentColor.opacity(0.12))
                Image(systemName: "keyboard").font(.system(size: 44, weight: .light)).foregroundStyle(Color.accentColor)
            }.frame(width: 120, height: 120)
        }
    }

    private var stepApps: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                title(L.obAppsTitle.t)
                body_(L.obAppsBody.t)
                if let a = adapters.first(where: { if case .needsSetting = readiness[$0.displayName] ?? .notInstalled { return true }; return false }) {
                    Text(L.showSetting(a.displayName)).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle()).onTapGesture { onShowSetting(a) }
                }
                Spacer()
                Button(L.continueBtn.t) { step = 3 }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            VStack(spacing: 6) {
                ForEach(adapters.filter { $0.isInstalled }.prefix(4), id: \.displayName) { a in
                    let r = readiness[a.displayName] ?? .unknown("")
                    HStack(spacing: 8) {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: a.bundlePrefixes[0]) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 22, height: 22)
                        }
                        Text(a.displayName).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer()
                        Text(label(r)).font(.system(size: 11)).foregroundStyle(color(r)).lineLimit(1).fixedSize()
                    }
                    .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }.frame(width: 215)
        }
    }

    private var stepTry: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                title(L.obTryTitle.t)
                body_(L.obTryBody.t)
                Spacer()
                HStack(spacing: 12) {
                    Button(L.done.t) { onFinish() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    Text(L.rightClickHint.t).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.14)))
                    Image(systemName: "playpause.fill").font(.system(size: 34, weight: .semibold))
                }
                .frame(width: 92, height: 92)
                .scaleEffect(waitingPulse ? 1.04 : 1)
                .onAppear { if !state.reduceMotion { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { waitingPulse = true } } }
                Text(state.lastEventAt == nil ? L.waiting.t : state.headline).font(.system(size: 11)).foregroundStyle(.secondary)
            }.frame(width: 190)
        }
    }

    private func title(_ t: String) -> some View { Text(t).font(.system(size: 19, weight: .bold)).tracking(-0.2) }
    private func body_(_ t: String) -> some View { Text(t).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
    private func label(_ r: Readiness) -> String { switch r { case .ready: return L.ready.t; case .needsSetting: return L.pillNeedsSetting.t; case .unknown: return L.pillOff.t; case .notInstalled: return L.pillNotInstalled.t } }
    private func color(_ r: Readiness) -> Color { switch r { case .ready: return .green; case .needsSetting: return .yellow; default: return .secondary } }
    private func refreshReadiness() {
        DispatchQueue.global(qos: .userInitiated).async {
            var r: [String: Readiness] = [:]
            for a in adapters { r[a.displayName] = a.readiness() }
            DispatchQueue.main.async { readiness = r }
        }
    }
}

/// Onboarding penceresi: cam, başlıksız, ortalanmış.
final class OnboardingWindow: NSWindow {
    init(view: OnboardingView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 640, height: 300),
                   styleMask: [.titled, .fullSizeContentView, .closable], backing: .buffered, defer: false)
        titleVisibility = .hidden; titlebarAppearsTransparent = true
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach { standardWindowButton($0)?.isHidden = true }
        isMovableByWindowBackground = true
        appearance = NSAppearance(named: .vibrantDark)
        isReleasedWhenClosed = false
        level = .floating   // onboarding geçicidir; başka pencerelerin altında kaybolmasın
        let effect = NSVisualEffectView()
        effect.material = .hudWindow; effect.blendingMode = .behindWindow; effect.state = .active
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: effect.leadingAnchor), host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                                     host.topAnchor.constraint(equalTo: effect.topAnchor), host.bottomAnchor.constraint(equalTo: effect.bottomAnchor)])
        contentView = effect
        center()
    }
    override func cancelOperation(_ sender: Any?) { close() }
}
