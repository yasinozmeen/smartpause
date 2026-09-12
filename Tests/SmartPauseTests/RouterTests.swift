import XCTest
@testable import SmartPause

/// Tuş davranışı sözleşmesi (docs/NOTES.md): tek basış geçirir, çift basış başlatır/durdurur; klasik modlar.
final class RouterTests: XCTestCase {
    override func setUp() { Settings.multiSourceMode = .switchKey; Settings.sourceMemory = 240 }

    func testNoAudioIsPassthrough() {
        let t = Bench(); t.audible = []
        XCTAssertFalse(t.press(), "ses yokken tuş sisteme bırakılmalı")
    }

    func testSystemStartedAppAppearsAfterPassthrough() {
        let t = Bench(); t.audible = []
        XCTAssertFalse(t.press(), "ses yokken tuş sisteme bırakılır")
        t.audible = [t.a]              // macOS tuşu alıp A'yı başlattı
        Thread.sleep(forTimeInterval: Router.systemStartWatchDelay + 0.15); t.router.queue.sync {}
        XCTAssertEqual(t.router.sources.map { $0.adapter.displayName }, ["AppA"], "macOS'un başlattığı uygulama widget'a girer")
        XCTAssertTrue(t.router.sources[0].isTarget)
        XCTAssertEqual(t.router.lastEvent, L.systemStarted("AppA"))
    }

    func testNothingStartsAfterPassthroughStaysEmpty() {
        let t = Bench(); t.audible = []
        t.press()
        Thread.sleep(forTimeInterval: Router.systemStartWatchDelay + 0.15); t.router.queue.sync {}
        XCTAssertTrue(t.router.sources.isEmpty)
    }

    func testSingleSourceSinglePressTogglesPauseThenResume() {
        let t = Bench(); t.audible = [t.a]
        XCTAssertTrue(t.press()); t.settle()
        XCTAssertFalse(t.a.playing, "tek kaynak: ilk basış durdurur")
        XCTAssertTrue(t.press()); t.settle()
        XCTAssertTrue(t.a.playing, "tek kaynak: ikinci basış sürdürür")
        XCTAssertEqual(t.a.commands, ["pause", "resume"])
    }

    func testTwoSourcesSinglePressSwitchesBackAndForth() {
        let t = Bench(); t.audible = [t.a, t.b]
        t.press(); t.settle()
        XCTAssertNotEqual(t.a.playing, t.b.playing, "geçişten sonra yalnız biri çalmalı")
        let firstPlaying = t.a.playing ? t.a : t.b
        let firstPaused = t.a.playing ? t.b : t.a
        t.audible = [firstPlaying]
        t.press(); t.settle()
        XCTAssertTrue(firstPaused.playing, "ikinci basış duranı sürdürür")
        XCTAssertFalse(firstPlaying.playing, "ikinci basış çalanı durdurur")
        // Widget listesi iki kaynağı da hatırlıyor; hedef üstte.
        XCTAssertEqual(t.router.sources.count, 2)
        XCTAssertTrue(t.router.sources[0].isTarget)
        XCTAssertEqual(t.router.sources[0].adapter.displayName, firstPaused.displayName)
    }

    func testDoublePressPlaysPausesSelected() {
        let t = Bench(); t.audible = [t.a, t.b]
        t.press(); t.press()   // çift basış
        t.settle()
        let target = t.router.sources.first { $0.isTarget }!
        let ad = target.adapter as! FakeAdapter
        XCTAssertFalse(ad.playing, "çift basış seçileni durdurur")
        XCTAssertTrue((t.a.playing || t.b.playing), "diğeri çalmaya devam eder")
        t.press(); t.press(); t.settle()
        XCTAssertTrue(ad.playing, "tekrar çift basış sürdürür")
    }

    func testPausedSourceIsForgottenAfterMemoryWindow() {
        Settings.sourceMemory = 0.2
        let t = Bench(); t.audible = [t.a]
        t.press(); t.settle()          // A durdu, listede "Duraklatıldı"
        XCTAssertEqual(t.router.sources.count, 1)
        Thread.sleep(forTimeInterval: 0.35)
        t.audible = [t.b]
        t.press(); t.settle()
        XCTAssertEqual(t.router.sources.map { $0.adapter.displayName }, ["AppB"], "hafıza penceresi dolan kaynak düşer")
    }

    func testClassicSwitchTargetMode() {
        Settings.multiSourceMode = .switchTarget
        let t = Bench(); t.audible = [t.a, t.b]
        t.press()
        let paused = t.a.playing ? t.b : t.a, playing = t.a.playing ? t.a : t.b
        XCTAssertFalse(paused.playing, "ilk basış birinciyi durdurur")
        t.press()   // hızlı ikinci basış → hedef geçer: birinci sürer, diğeri durur
        XCTAssertTrue(paused.playing); XCTAssertFalse(playing.playing)
    }

    func testClassicSilenceAllMode() {
        Settings.multiSourceMode = .silenceAll
        let t = Bench(); t.audible = [t.a, t.b]
        t.press(); t.press()
        XCTAssertFalse(t.a.playing); XCTAssertFalse(t.b.playing, "ikinci basış hepsini susturur")
    }

    func testTrackChangeGoesToPlayingSource() {
        let t = Bench(); t.audible = [t.a]
        XCTAssertTrue(t.router.queue.sync { t.router.handleTrackChange(forward: true) })
        t.router.queue.sync {}
        XCTAssertEqual(t.a.commands.last, "next")
        t.audible = []
        XCTAssertFalse(t.router.queue.sync { t.router.handleTrackChange(forward: false) }, "çalan yoksa parça tuşu sisteme gider")
    }
}
