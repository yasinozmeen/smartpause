import Foundation

/// Chromium tabanlı tarayıcılar: tüm sekmeler taranır, çalan <video>/<audio> durdurulur.
/// Gerektirir: Görünüm > Geliştirici > "Apple Events'ten JavaScript'e izin ver".
/// Sürdürme: en son durdurulan sekme URL ile bulunur ve ilk media elementi oynatılır.
final class ChromiumAdapter: AppAdapter {
    let displayName: String
    let bundlePrefixes: [String]
    let appName: String
    private var lastPausedURL: String?

    init(displayName: String, bundlePrefixes: [String], appName: String) {
        self.displayName = displayName; self.bundlePrefixes = bundlePrefixes; self.appName = appName
    }

    static let settingHint = "Görünüm › Geliştirici › \"Apple Events'ten JavaScript'e izin ver\" açılmalı"
    private var cachedControllable: (value: Bool, at: Date)?
    /// JS izni kapalıysa passthrough. Sonuç 60 sn önbelleklenir; tuş anında AppleScript maliyeti tekrarlanmaz.
    func isControllable() -> Bool {
        if let c = cachedControllable, Date().timeIntervalSince(c.at) < 60 { return c.value }
        let v: Bool
        if case .needsSetting = readiness() { v = false } else { v = true }
        cachedControllable = (v, Date())
        return v
    }

    func readiness() -> Readiness {
        guard isInstalled else { return .notInstalled }
        guard isRunning else { return .unknown("kapalı, ayar açıkken kontrol edilir") }
        switch AppleScript.runDetailed("tell application \"\(appName)\" to execute active tab of front window javascript \"1\"") {
        case .success: return .ready
        case .failure(let f): return f.code == 12 ? .needsSetting(Self.settingHint) : .unknown("pencere yok")
        }
    }

    private static let pauseJS = "(function(){var m=[...document.querySelectorAll('video,audio')].find(e=>!e.paused);if(m){m.pause();return location.href}return 'none'})()"
    private static let resumeJS = "(function(){var m=[...document.querySelectorAll('video,audio')][0];if(m){m.play();return 'ok'}return 'none'})()"

    func pause() -> Bool {
        let r = AppleScript.run("""
        tell application "\(appName)"
          repeat with w in windows
            repeat with t in tabs of w
              try
                set r to execute t javascript "\(Self.pauseJS)"
                if r is not "none" then return r
              end try
            end repeat
          end repeat
          return "none"
        end tell
        """)
        guard let r, r != "none" else { return false }
        lastPausedURL = r
        return true
    }

    func resume() -> Bool {
        guard let url = lastPausedURL else { return false }
        let r = AppleScript.run("""
        tell application "\(appName)"
          repeat with w in windows
            repeat with t in tabs of w
              if URL of t is "\(url)" then
                try
                  return execute t javascript "\(Self.resumeJS)"
                end try
              end if
            end repeat
          end repeat
          return "none"
        end tell
        """)
        return r == "ok"
    }

    static let brave  = ChromiumAdapter(displayName: "Brave", bundlePrefixes: ["com.brave.Browser"], appName: "Brave Browser")
    static let chrome = ChromiumAdapter(displayName: "Google Chrome", bundlePrefixes: ["com.google.Chrome"], appName: "Google Chrome")
    static let arc    = ChromiumAdapter(displayName: "Arc", bundlePrefixes: ["company.thebrowser.Browser"], appName: "Arc")
}
