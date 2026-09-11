import SwiftUI
import ServiceManagement

/// Sağ tık paneli (tasarım sözleşmesi "Panel"): başlık + üç sekme + kartlar + alt düğmeler.
struct PanelView: View {
    @ObservedObject var state: AppState
    let adapters: [AppAdapter]
    var onQuit: () -> Void
    var onHelp: () -> Void
    var onSetting: (AppAdapter) -> Void
    var onChanged: () -> Void
    var onOnboarding: () -> Void

    enum Tab: CaseIterable { case behavior, apps, setup
        var title: String { switch self { case .behavior: return L.tabBehavior.t; case .apps: return L.tabApps.t; case .setup: return L.tabSetup.t } }
    }
    @State private var tab: Tab = .behavior
    @State private var readiness: [String: Readiness] = [:]

    var body: some View {
        VStack(spacing: 12) {
            header
            tabs
            Group {
                switch tab {
                case .behavior: behavior
                case .apps: apps
                case .setup: setup
                }
            }
            .transition(.opacity)
            footer
        }
        .padding(EdgeInsets(top: 14, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 360)
        .animation(state.reduceMotion ? nil : .easeOut(duration: 0.18), value: tab)
        .onAppear { refreshReadiness() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.10))
                Image(systemName: "playpause.fill").font(.system(size: 18, weight: .semibold))
            }.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("SmartPause").font(.system(size: 15, weight: .bold))
                Text("\(state.statusSentence) · \(state.lastEventSentence)").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Circle().fill(state.trusted && state.enabled ? Color.green : Color.yellow).frame(width: 8, height: 8)
                .shadow(color: (state.trusted && state.enabled ? Color.green : Color.yellow).opacity(0.5), radius: 3)
                .help(state.trusted ? L.helpTapLive.t : L.helpNoPermission.t)
        }.padding(.horizontal, 4)
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { t in
                Text(t.title).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tab == t ? .primary : .secondary)
                    .padding(.vertical, 6).frame(maxWidth: .infinity)
                    .background(tab == t ? Color.white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { tab = t }
            }
        }.padding(3).background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var behavior: some View {
        VStack(spacing: 8) {
            card("power", L.enabledTitle.t, L.enabledDesc.t) {
                Toggle("", isOn: Binding(get: { state.enabled }, set: { state.enabled = $0; onChanged() })).labelsHidden().toggleStyle(.switch)
            }
            card("rectangle.topthird.inset.filled", L.showWidgetTitle.t, L.showWidgetDesc.t) {
                Toggle("", isOn: Binding(get: { state.showHUD }, set: { state.showHUD = $0; Settings.showHUD = $0 })).labelsHidden().toggleStyle(.switch)
            }
            stackedCard("timer", L.durationTitle.t, L.durationDesc.t) {
                optionRow(Settings.hudDurationOptions, selected: state.hudDuration, label: { L.seconds($0 == floor($0) ? "\(Int($0))" : "\($0)".replacingOccurrences(of: ".", with: state.language.decimalSeparator)) }) { v in
                    state.hudDuration = v; Settings.hudDuration = v
                }
            }
            stackedCard("clock.arrow.circlepath", L.memoryTitle.t, L.memoryDesc.t) {
                optionRow(Settings.sourceMemoryOptions, selected: state.sourceMemory, label: { $0 < 3600 ? L.minutes(Int($0 / 60)) : L.oneHour.t }) { v in
                    state.sourceMemory = v; Settings.sourceMemory = v
                }
            }
            card("music.note", L.blockMusicTitle.t, L.blockMusicDesc.t) {
                Toggle("", isOn: Binding(get: { state.blockMusic }, set: { state.blockMusic = $0; Settings.blockMusic = $0; onChanged() })).labelsHidden().toggleStyle(.switch)
            }
            stackedCard("arrow.left.arrow.right", L.keyBehaviorTitle.t, L.keyBehaviorDesc.t) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(MultiSourceMode.allCases, id: \.self) { m in
                        HStack(spacing: 8) {
                            Image(systemName: state.multiSourceMode == m ? "largecircle.fill.circle" : "circle").font(.system(size: 12)).foregroundStyle(state.multiSourceMode == m ? Color.accentColor : .secondary)
                            Text(m.title).font(.system(size: 12, weight: state.multiSourceMode == m ? .semibold : .regular))
                        }
                        .padding(.vertical, 3).contentShape(Rectangle())
                        .onTapGesture { state.multiSourceMode = m; Settings.multiSourceMode = m }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            stackedCard("menubar.rectangle", L.menuIconTitle.t, L.menuIconDesc.t) {
                HStack(spacing: 2) {
                    ForEach(MenuBarIcon.allCases, id: \.self) { ic in
                        Image(systemName: ic.rawValue).font(.system(size: 13, weight: .medium))
                            .frame(width: 32, height: 26)
                            .background(state.menuBarIcon == ic ? Color.white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .contentShape(Rectangle())
                            .help(ic.title)
                            .onTapGesture { state.menuBarIcon = ic; Settings.menuBarIcon = ic; onChanged() }
                    }
                }.padding(2).background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            card("arrow.up.circle", L.loginTitle.t, L.loginDesc.t) {
                Toggle("", isOn: Binding(get: { state.launchAtLogin }, set: { setLaunchAtLogin($0) })).labelsHidden().toggleStyle(.switch)
            }
        }
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.appsIntro.t)
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 4)
            VStack(spacing: 2) {
                ForEach(adapters, id: \.displayName) { a in
                    let r = readiness[a.displayName] ?? .notInstalled
                    HStack(spacing: 10) {
                        appIcon(a).frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.displayName).font(.system(size: 13, weight: .medium))
                            if let n = r.note { Text(n).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                        }
                        Spacer()
                        pill(for: r)
                        if case .needsSetting = r { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary) }
                    }
                    .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    .contentShape(Rectangle())
                    .onTapGesture { if case .needsSetting = r { onSetting(a) } }
                }
            }
            .padding(4)
            .background(cardBackground)
            HStack(spacing: 4) {
                Text(L.appsMissing.t).font(.system(size: 12)).foregroundStyle(.secondary)
                Text(L.requestSupport.t).font(.system(size: 12)).foregroundStyle(Color.accentColor).onTapGesture { onHelp() }
            }.padding(.horizontal, 4)
        }
    }

    private var setup: some View {
        VStack(spacing: 8) {
            stackedCard("globe", L.languageTitle.t, L.languageDesc.t) {
                HStack(spacing: 2) {
                    ForEach(Language.allCases, id: \.self) { l in
                        Text(l.title).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(state.language == l ? .primary : .secondary)
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(state.language == l ? Color.white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .contentShape(Rectangle())
                            .onTapGesture { Settings.language = l; state.language = l; state.headline = L.ready.t; onChanged() }
                    }
                }.padding(2).background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            card(state.trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", L.accessTitle.t, state.trusted ? L.accessGranted.t : L.accessNeeded.t) {
                if !state.trusted { Button(L.open.t) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }.controlSize(.small) }
            }
            card("hand.raised", L.automationTitle.t, L.automationDesc.t) { EmptyView() }
            card("safari", L.browserJSTitle.t, L.browserJSDesc.t) { EmptyView() }
            card("doc.text", L.logTitle.t, L.logDesc.t) {
                Button(L.show.t) { NSWorkspace.shared.selectFile(NSHomeDirectory() + "/Library/Logs/SmartPause.log", inFileViewerRootedAtPath: "") }.controlSize(.small)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            footerButton("questionmark.circle", L.setupHelp.t) { onOnboarding() }
            footerButton("power", L.quit.t) { onQuit() }
        }
    }

    // MARK: - parçalar
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.07)))
    }
    private func card<C: View>(_ symbol: String, _ title: String, _ desc: String, @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.14))
                Image(systemName: symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.accentColor)
            }.frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(desc).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12))
        .background(cardBackground)
    }
    /// Geniş kontrol (segment, simge seçici) için: metin üstte, kontrol altta sağa yaslı.
    private func stackedCard<C: View>(_ symbol: String, _ title: String, _ desc: String, @ViewBuilder control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.14))
                    Image(systemName: symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.accentColor)
                }.frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(desc).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack { Spacer(); control() }
        }
        .padding(EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12))
        .background(cardBackground)
    }
    /// Seçenek düğmeleri (segment yerine: değerler sayı, metin kısa).
    private func optionRow(_ options: [Double], selected: Double, label: @escaping (Double) -> String, pick: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { v in
                Text(label(v)).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(v == selected ? .primary : .secondary)
                    .padding(.vertical, 5).padding(.horizontal, 9)
                    .background(v == selected ? Color.white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { pick(v) }
            }
        }.padding(2).background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    private func footerButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)); Text(title).font(.system(size: 12, weight: .semibold)) }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(cardBackground).contentShape(Rectangle()).onTapGesture(perform: action)
    }
    private func pill(for r: Readiness) -> some View {
        let (t, c): (String, Color) = {
            switch r {
            case .ready: return (L.ready.t, .green)
            case .needsSetting: return (L.pillNeedsSetting.t, .yellow)
            case .unknown: return (L.pillOff.t, .secondary)
            case .notInstalled: return (L.pillNotInstalled.t, .secondary)
            }
        }()
        return Text(t).font(.system(size: 10, weight: .semibold)).foregroundStyle(c)
            .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)).background(c.opacity(0.16), in: Capsule())
    }
    private func appIcon(_ a: AppAdapter) -> some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: a.bundlePrefixes[0]) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.12))
                    .overlay(Image(systemName: "app.dashed").font(.system(size: 12)).foregroundStyle(.secondary))
            }
        }
    }
    private func refreshReadiness() {
        DispatchQueue.global(qos: .userInitiated).async {
            var r: [String: Readiness] = [:]
            for a in adapters { r[a.displayName] = a.readiness() }
            DispatchQueue.main.async { readiness = r }
        }
    }
    private func setLaunchAtLogin(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; state.launchAtLogin = on; Settings.launchAtLogin = on }
        catch { Log.write("[panel] girişte başlat ayarlanamadı: \(error)") }
    }
}
