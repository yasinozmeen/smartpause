import AppKit

/// noTunes davranışı: Apple Music kendiliğinden açılırsa hemen kapat (public NSWorkspace API).
/// Kullanıcı Music'i bilerek açmak isterse menüden kapatılır.
final class MusicBlocker {
    var enabled = false
    private var token: NSObjectProtocol?

    init() {
        token = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, self.enabled,
                  let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.Music" else { return }
            app.terminate()
        }
    }
}
