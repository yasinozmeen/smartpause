import Foundation

/// Bir uygulamaya play/pause iletebilen adapter. Adapter'ı olmayan uygulama → passthrough.
protocol AppAdapter {
    var displayName: String { get }
    /// Bu adapter'ın sorumlu olduğu bundle id önekleri (helper process'ler de eşleşir).
    var bundlePrefixes: [String] { get }
    /// Uygulamanın gerçekten çaldığını bildirir; nil = bilinmiyor (Core Audio'ya güven).
    /// Neden: Core Audio, durdurulan uygulamayı bir süre daha "ses çıkarıyor" gösterir.
    func isPlaying() -> Bool?
    /// Çalanı durdurur. Başarılıysa true.
    func pause() -> Bool
    /// En son durdurulanı sürdürür. Başarılıysa true.
    func resume() -> Bool
}

extension AppAdapter {
    func isPlaying() -> Bool? { nil }
    func matches(bundleID: String) -> Bool {
        bundlePrefixes.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }
}

enum AppleScript {
    @discardableResult
    static func run(_ source: String) -> String? {
        var err: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err { NSLog("AppleScript hata: \(err)"); return nil }
        return result?.stringValue ?? ""
    }
}
