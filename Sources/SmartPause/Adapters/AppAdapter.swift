import Foundation
import AppKit

/// Bir uygulamaya play/pause iletebilen adapter. Adapter'ı olmayan uygulama → passthrough.
enum Readiness {
    case notInstalled, ready, unknown(String), needsSetting(String)
    var symbol: String { switch self { case .ready: return "✓"; case .notInstalled: return "—"; case .unknown: return "·"; case .needsSetting: return "⚠︎" } }
    var note: String? { switch self { case .ready, .notInstalled: return nil; case .unknown(let s), .needsSetting(let s): return s } }
}

protocol AppAdapter {
    /// Menüde gösterilecek hazırlık durumu. Uygulamayı ASLA başlatmamalı.
    func readiness() -> Readiness
    /// Tuş anında hızlı karar: bu adapter şu an komut gönderebilir mi? false → tuş sisteme bırakılır
    /// (tarayıcı zaten "Şu An Çalan" kaydındaysa sistem doğru yere iletir).
    func isControllable() -> Bool
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
    /// Sonraki/önceki parça. Desteklenmiyorsa false → tuş sisteme bırakılır.
    func next() -> Bool
    func previous() -> Bool
    /// Uygulama yüklü / açık mı (varsayılan: bundle id'ye bakar; testlerde sahte adapter geçersiz kılar).
    var isInstalled: Bool { get }
    var isRunning: Bool { get }
}

extension AppAdapter {
    var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundlePrefixes[0]) != nil }
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundlePrefixes[0]).isEmpty }
    func readiness() -> Readiness { isInstalled ? .ready : .notInstalled }
    func isControllable() -> Bool { true }
    func next() -> Bool { false }
    func previous() -> Bool { false }
    func isPlaying() -> Bool? { nil }
    func matches(bundleID: String) -> Bool {
        bundlePrefixes.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }
}

enum AppleScript {
    struct Failure: Error { let code: Int; let message: String }
    /// Apple Event yanıt süresi sınırı. Varsayılan 120 sn: askıda kalan bir tarayıcı sekmesi tuşları 2 dk kilitliyordu (log 2026-09-10 23:35).
    static let timeoutSeconds = 4
    static func runDetailed(_ source: String) -> Result<String, Failure> {
        var err: NSDictionary?
        let t0 = Date()
        let wrapped = "with timeout of \(timeoutSeconds) seconds\n\(source)\nend timeout"
        let result = NSAppleScript(source: wrapped)?.executeAndReturnError(&err)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        if ms > 400 { Log.write("[applescript] YAVAŞ \(ms) ms: \(source.prefix(60).replacingOccurrences(of: "\n", with: " "))") }
        if let err {
            let f = Failure(code: err[NSAppleScript.errorNumber] as? Int ?? -1, message: err[NSAppleScript.errorMessage] as? String ?? "\(err)")
            Log.write("AppleScript hata \(f.code): \(f.message)"); return .failure(f)
        }
        return .success(result?.stringValue ?? "")
    }
    @discardableResult
    static func run(_ source: String) -> String? { try? runDetailed(source).get() }
}
