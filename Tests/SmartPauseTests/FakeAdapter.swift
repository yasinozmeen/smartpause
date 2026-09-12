import Foundation
@testable import SmartPause

/// Gerçek uygulama yerine geçen sahte adapter: durumu bellekte tutar, hangi komutların geldiğini kaydeder.
final class FakeAdapter: AppAdapter {
    let displayName: String
    let bundlePrefixes: [String]
    var playing: Bool
    var commands: [String] = []
    init(_ name: String, bundle: String, playing: Bool) { displayName = name; bundlePrefixes = [bundle]; self.playing = playing }

    func readiness() -> Readiness { .ready }
    func isControllable() -> Bool { true }
    func isPlaying() -> Bool? { playing }
    func pause() -> Bool { commands.append("pause"); guard playing else { return false }; playing = false; return true }
    func resume() -> Bool { commands.append("resume"); playing = true; return true }
    func next() -> Bool { commands.append("next"); return true }
    func previous() -> Bool { commands.append("previous"); return true }
    var isInstalled: Bool { true }
    var isRunning: Bool { true }

    /// Core Audio'nun bu uygulama için üreteceği kayıt. Core Audio, duran uygulamayı bir süre daha "çalıyor" gösterir;
    /// bu yüzden `stale: true` ile durmuş kaynağı da listede tutabiliriz.
    func process(pid: pid_t) -> AudioProcess {
        AudioProcess(pid: pid, bundleID: bundlePrefixes[0], responsiblePID: pid, responsibleBundleID: bundlePrefixes[0], name: displayName)
    }
}

/// Test tezgâhı: sahte uygulamalar + Core Audio'nun "çalıyor" listesi.
final class Bench {
    let a = FakeAdapter("AppA", bundle: "test.a", playing: true)
    let b = FakeAdapter("AppB", bundle: "test.b", playing: true)
    var audible: [FakeAdapter] = []
    lazy var router = Router(adapters: [a, b], detect: { [weak self] in guard let self else { return [] }; return
        self.audible.enumerated().map { i, ad in ad.process(pid: pid_t(1000 + i)) }
    }, isAlive: { _ in true })

    /// Bir tuş basışı: router kuyruğunda senkron karar.
    @discardableResult func press() -> Bool { router.queue.sync { router.handlePlayPause() } }
    /// Tek basış penceresinin (350 ms) dolmasını bekle.
    func settle() { Thread.sleep(forTimeInterval: Router.doublePressWindow + 0.15); router.queue.sync {} }
}
