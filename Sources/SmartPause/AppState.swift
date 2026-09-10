import AppKit
import SwiftUI

/// Arayüzün tek gerçeklik kaynağı. Router yazar, widget/panel/onboarding okur.
final class AppState: ObservableObject {
    static let shared = AppState()

    enum SourceKind { case controlled, unknown }
    struct Source: Identifiable, Equatable {
        let id: String            // adapter adı ya da bundle id
        let name: String
        let icon: NSImage?
        var isPlaying: Bool
        var isTarget: Bool
        var kind: SourceKind = .controlled
        var pulse: Bool = false   // bu güncellemede durduruldu → simge nabzı
        static func == (l: Source, r: Source) -> Bool { l.id == r.id && l.isPlaying == r.isPlaying && l.isTarget == r.isTarget && l.kind == r.kind }
    }

    @Published var sources: [Source] = []
    @Published var headline = "Hazır"
    @Published var hint: String? = nil
    @Published var lastEventAt: Date? = nil
    @Published var trusted = MediaKeyTap.isTrusted
    @Published var enabled = true
    @Published var showHUD = Settings.showHUD
    @Published var blockMusic = Settings.blockMusic
    @Published var multiSourceMode = Settings.multiSourceMode
    @Published var launchAtLogin = Settings.launchAtLogin
    @Published var menuBarIcon = Settings.menuBarIcon
    @Published var hudDuration = Settings.hudDuration
    @Published var sourceMemory = Settings.sourceMemory
    @Published var hudRevision = 0   // her artışta widget yeniden gösterilir

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Durum cümlesi (panel başlığı).
    var statusSentence: String {
        if !trusted { return "Erişilebilirlik izni bekleniyor" }
        if !enabled { return "Kapalı — tuş sisteme gidiyor" }
        if let t = sources.first(where: { $0.isTarget }) { return t.isPlaying ? "\(t.name) çalıyor" : "\(t.name) duraklatıldı" }
        return "Tuşu bekliyorum"
    }
    var lastEventSentence: String {
        guard let at = lastEventAt else { return "Henüz bir şey olmadı" }
        let s = Int(Date().timeIntervalSince(at))
        let ago = s < 60 ? "\(s) sn önce" : s < 3600 ? "\(s / 60) dk önce" : "\(s / 3600) sa önce"
        return "Son: \(headline.lowercased()), \(ago)"
    }
}
