import Foundation

/// Spotify / Music / VLC gibi tek komutla toggle edilen uygulamalar.
struct ScriptableAdapter: AppAdapter {
    let displayName: String
    let bundlePrefixes: [String]
    let appName: String
    let toggleCommand: String
    let playingQuery: String
    let nextCommand: String
    let previousCommand: String

    private func toggle() -> Bool {
        AppleScript.run("tell application \"\(appName)\" to \(toggleCommand)") != nil
    }
    func isPlaying() -> Bool? {
        guard let r = AppleScript.run("tell application \"\(appName)\" to \(playingQuery)") else { return nil }
        return r == "true"
    }
    func pause() -> Bool { toggle() }
    func next() -> Bool { AppleScript.run("tell application \"\(appName)\" to \(nextCommand)") != nil }
    func previous() -> Bool { AppleScript.run("tell application \"\(appName)\" to \(previousCommand)") != nil }
    func resume() -> Bool { toggle() }

    static let spotify = ScriptableAdapter(displayName: "Spotify", bundlePrefixes: ["com.spotify.client"], appName: "Spotify", toggleCommand: "playpause", playingQuery: "(player state is playing) as string", nextCommand: "next track", previousCommand: "previous track")
    static let music   = ScriptableAdapter(displayName: "Apple Music", bundlePrefixes: ["com.apple.Music"], appName: "Music", toggleCommand: "playpause", playingQuery: "(player state is playing) as string", nextCommand: "next track", previousCommand: "previous track")
    static let vlc     = ScriptableAdapter(displayName: "VLC", bundlePrefixes: ["org.videolan.vlc"], appName: "VLC", toggleCommand: "play", playingQuery: "playing as string", nextCommand: "next", previousCommand: "previous") // VLC'de play toggle'dır
}
