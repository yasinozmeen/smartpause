import SwiftUI

/// Widget içeriği (Native Glass sözleşmesi): 296 px, satır 46 px, dış yarıçap 18 / iç 12.
struct HUDView: View {
    @ObservedObject var state: AppState
    var onSelect: (AppState.Source) -> Void
    var onToggle: (AppState.Source) -> Void
    var onHelp: () -> Void
    /// Yer değiştirme hareketi: yükselen satır öne (ölçek, gölge), inen satır arkaya (küçülür, solar); ikisi de kısa bir
    /// hız bulanıklığı alır. Vurgu ilk satırda SABİT durur, satırlar onun altından geçer (Yasin, 2026-09-11).
    @State private var rising: Set<String> = []
    @State private var falling: Set<String> = []
    private static let swapCurve = Animation.timingCurve(0.3, 0.75, 0.2, 1, duration: 0.62)

    var body: some View {
        VStack(spacing: 2) {
            if !state.trusted {
                permissionRow
            } else {
                ForEach(state.sources) { s in
                    let up = rising.contains(s.id), down = falling.contains(s.id)
                    SourceRowView(source: s, reduceMotion: state.reduceMotion)
                        .help(L.hudRowHelp.t)
                        .scaleEffect(up ? 1.06 : down ? 0.94 : 1)
                        .shadow(color: .black.opacity(up ? 0.6 : 0), radius: up ? 18 : 0, y: up ? 12 : 0)
                        .blur(radius: (up || down) ? 1.6 : 0)
                        .opacity(down ? 0.55 : 1)
                        .zIndex(up ? 2 : down ? 0 : 1)
                }
                if let h = state.hint {
                    HStack(spacing: 6) {
                        Image(systemName: state.sources.contains { $0.kind == .unknown } ? "arrow.up.right" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(h)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(state.sources.contains { $0.kind == .unknown } ? Color.accentColor : .secondary)
                    .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(h)   // metin değişince eskisi önce söner, yenisi sonra belirir (üst üste binmez)
                    .transition(.asymmetric(insertion: .opacity.animation(.easeIn(duration: 0.2).delay(0.3)),
                                            removal: .opacity.animation(.easeOut(duration: 0.12))))
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 8, trailing: 10))
        .frame(width: 296)
        .background(alignment: .top) {
            // Sabit vurgu: her zaman ilk satırın yeri.
            if state.trusted, !state.sources.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.10))
                    .frame(height: 46).padding(.horizontal, 10).padding(.top, 10)
            }
        }
        .animation(state.reduceMotion ? .linear(duration: 0.15) : Self.swapCurve, value: state.sources)
        .onChange(of: state.sources.map(\.id)) { old, new in
            guard !state.reduceMotion else { return }
            var r = Set<String>(), f = Set<String>()
            for (i, id) in new.enumerated() {
                guard let j = old.firstIndex(of: id), j != i else { continue }
                if i < j { r.insert(id) } else { f.insert(id) }
            }
            guard !r.isEmpty || !f.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.16)) { rising = r; falling = f }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.28)) { rising = []; falling = [] }
            }
        }
    }

    private var permissionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 20)).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(L.cantHear.t).font(.system(size: 13, weight: .semibold))
                Text(L.needAccess.t).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(L.settings.t) { onHelp() }.buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
    }
}

struct SourceRowView: View {
    let source: AppState.Source
    let reduceMotion: Bool
    @State private var ring: CGFloat = 1
    @State private var ringOpacity: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 34, height: 34)
                    .scaleEffect(ring).opacity(ringOpacity)
                Group {
                    if let i = source.icon { Image(nsImage: i).resizable().interpolation(.high) }
                    else { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.15)) }
                }
                .frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(source.name).font(.system(size: 13, weight: source.isTarget ? .semibold : .medium)).lineLimit(1)
                Text(statusText).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 4)
            Image(systemName: glyph)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(source.kind == .unknown ? Color.yellow : (source.isTarget ? Color.primary : Color.secondary))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        .opacity(source.isTarget || source.kind == .unknown ? 1 : 0.78)
        .onAppear { if source.pulse && !reduceMotion { pulse() } }
        .onChange(of: source.pulse) { _, p in if p && !reduceMotion { pulse() } }
    }

    private var statusText: String {
        switch source.kind {
        case .unknown: return L.passedToSystem.t
        case .controlled: return source.isPlaying ? L.playing.t : L.paused.t
        }
    }
    private var glyph: String {
        switch source.kind {
        case .unknown: return "exclamationmark.triangle.fill"
        case .controlled: return source.isPlaying ? (source.isTarget ? "play.fill" : "speaker.wave.2.fill") : "pause.fill"
        }
    }
    /// Simge nabzı: 1 tur, 900 ms (yalnız durdurmada).
    private func pulse() {
        ring = 1; ringOpacity = 0.35
        withAnimation(.easeOut(duration: 0.9)) { ring = 1.22; ringOpacity = 0 }
    }
}
