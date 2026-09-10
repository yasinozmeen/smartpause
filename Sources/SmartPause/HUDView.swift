import SwiftUI

/// Widget içeriği (Native Glass sözleşmesi): 296 px, satır 46 px, dış yarıçap 18 / iç 12.
struct HUDView: View {
    @ObservedObject var state: AppState
    var onSelect: (AppState.Source) -> Void
    var onToggle: (AppState.Source) -> Void
    var onHelp: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            if !state.trusted {
                permissionRow
            } else {
                ForEach(state.sources) { s in
                    SourceRowView(source: s, reduceMotion: state.reduceMotion)
                        .help("Tek tık: hedef yap · Çift tık: başlat/durdur")
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
                    .transition(.opacity)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 8, trailing: 10))
        .frame(width: 296)
        .animation(state.reduceMotion ? .linear(duration: 0.15) : .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.26), value: state.sources)
    }

    private var permissionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 20)).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tuşu duyamıyorum").font(.system(size: 13, weight: .semibold))
                Text("Erişilebilirlik izni gerekli").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("Ayarlar") { onHelp() }.buttonStyle(.borderedProminent).controlSize(.small)
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
        .background(source.isTarget ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(source.isTarget || source.kind == .unknown ? 1 : 0.78)
        .onAppear { if source.pulse && !reduceMotion { pulse() } }
        .onChange(of: source.pulse) { _, p in if p && !reduceMotion { pulse() } }
    }

    private var statusText: String {
        switch source.kind {
        case .unknown: return "Tuşu sisteme bıraktım"
        case .controlled: return source.isPlaying ? "Çalıyor" : "Duraklatıldı"
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
