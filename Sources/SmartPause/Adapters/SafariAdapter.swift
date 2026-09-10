import Foundation

/// Safari: Geliştirici menüsünde "Apple Events'ten JavaScript'e izin ver" gerekir. Henüz canlı test edilmedi.
final class SafariAdapter: AppAdapter {
    let displayName = "Safari"
    let bundlePrefixes = ["com.apple.Safari"]
    private var lastPausedURL: String?

    static let settingHint = "Geliştir › \"Apple Events'ten JavaScript'e İzin Ver\" açılmalı (Ayarlar › İleri Düzey › Geliştir menüsü)"
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
        switch AppleScript.runDetailed("tell application \"Safari\" to do JavaScript \"1\" in current tab of front window") {
        case .success: return .ready
        case .failure(let f): return f.code == 8 ? .needsSetting(Self.settingHint) : .unknown("pencere yok")
        }
    }

    /// Gerçek durum: herhangi bir sekmede çalan media var mı? (Core Audio bayat kaydına güvenilmez; ana kuyrukta çağrılır.)
    func isPlaying() -> Bool? {
        guard isRunning, isControllable() else { return nil }
        let r = AppleScript.run("""
        tell application "Safari"
          repeat with w in windows
            repeat with t in tabs of w
              try
                if (do JavaScript "[...document.querySelectorAll('video,audio')].some(e=>!e.paused)" in t) as string is "true" then return "true"
              end try
            end repeat
          end repeat
          return "false"
        end tell
        """)
        return r.map { $0 == "true" }
    }

    func pause() -> Bool {
        let r = AppleScript.run("""
        tell application "Safari"
          repeat with w in windows
            repeat with t in tabs of w
              try
                set r to do JavaScript "(function(){var m=[...document.querySelectorAll('video,audio')].find(e=>!e.paused);if(m){m.pause();return location.href}return 'none'})()" in t
                if r is not "none" then return r
              end try
            end repeat
          end repeat
          return "none"
        end tell
        """)
        guard let r, r != "none" else { return false }
        lastPausedURL = r; return true
    }
    func resume() -> Bool {
        guard let url = lastPausedURL else { return false }
        let r = AppleScript.run("""
        tell application "Safari"
          repeat with w in windows
            repeat with t in tabs of w
              if URL of t is "\(url)" then
                try
                  return do JavaScript "(function(){var m=[...document.querySelectorAll('video,audio')][0];if(m){m.play();return 'ok'}return 'none'})()" in t
                end try
              end if
            end repeat
          end repeat
          return "none"
        end tell
        """)
        return r == "ok"
    }
}
