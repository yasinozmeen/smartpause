import XCTest
@testable import SmartPause

/// Tuş davranışı sözleşmesi (docs/NOTES.md): tek basış geçirir, çift basış başlatır/durdurur; klasik modlar.
final class RouterTests: XCTestCase {
    override func setUp() { Settings.multiSourceMode = .switchKey; Settings.sourceMemory = 240; Router.musicVerifyDelay = 0.05 }

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

    func testDoublePressWithSingleSourceOpensMusicAppAndPlays() {
        let t = Bench(); t.m.running = false; t.audible = [t.a]
        t.press(); t.press()                                 // yalnız A varken çift basış
        Thread.sleep(forTimeInterval: 0.5); t.router.queue.sync {}
        XCTAssertFalse(t.a.playing, "çalan kaynak durur")
        XCTAssertEqual(t.launches, ["Music"], "kapalı müzik uygulaması açılır")
        XCTAssertTrue(t.m.playing, "müzik kaldığı yerden çalar")
        XCTAssertTrue(t.router.sources.first?.isTarget == true && t.router.sources.first?.adapter.displayName == "Music")
    }

    func testDoublePressWithSingleSourceResumesRunningMusicAppWithoutLaunching() {
        let t = Bench(); t.m.running = true; t.audible = [t.a]
        t.press(); t.press()
        Thread.sleep(forTimeInterval: 0.3); t.router.queue.sync {}
        XCTAssertEqual(t.launches, [], "açık uygulama yeniden açılmaz")
        XCTAssertTrue(t.m.playing)
        XCTAssertFalse(t.a.playing)
    }

    func testDoublePressWithTwoSourcesStillTogglesSelected() {
        let t = Bench(); t.audible = [t.a, t.b]
        t.press(); t.press(); t.settle()
        XCTAssertEqual(t.launches, [], "iki kaynak varken çift basış eskisi gibi seçileni başlatır/durdurur")
        XCTAssertFalse(t.m.playing)
    }

    func testSourcesSurviveRestart() {
        let first = Bench(); first.audible = [first.a]
        first.press(); first.settle()                       // A durdu, hedef A
        XCTAssertFalse(first.a.playing)

        let second = Bench(memory: first.memory)            // uygulama yeniden başladı
        XCTAssertEqual(second.router.sources.map { $0.adapter.displayName }, ["AppA"], "hafızadaki kaynak geri gelir")
        XCTAssertTrue(second.router.sources[0].isTarget)
        XCTAssertFalse(second.router.sources[0].isPlaying, "geri gelen kaynak duraklatılmış görünür")
        second.a.playing = false; second.audible = []
        XCTAssertTrue(second.press(), "ses yokken tuş macOS'a değil hafızadaki hedefe gider"); second.settle()
        XCTAssertEqual(second.a.commands, ["resume"])
    }

    func testExpiredSourcesAreNotRestored() {
        Settings.sourceMemory = 0.2
        let first = Bench(); first.audible = [first.a]
        first.press(); first.settle()
        Thread.sleep(forTimeInterval: 0.35)
        let second = Bench(memory: first.memory)
        XCTAssertTrue(second.router.sources.isEmpty, "hafıza penceresi dolan kaynak geri yüklenmez")
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

    func testClassicSwitchTargetModeWhenOnlyOneSourcePlayingInitially() {
        Settings.multiSourceMode = .switchTarget
        let t = Bench()
        t.router.multiSourceWindow = 0.2

        // Önce AppB çalıştı ve durduruldu (listede duraklatılmış olarak var)
        t.audible = [t.b]
        t.press()
        t.audible = []
        XCTAssertFalse(t.b.playing)

        // Çoklu basış penceresinin geçmesini bekle (böylece sonraki basış bağımsız ilk basış olur)
        Thread.sleep(forTimeInterval: 0.25)

        // Şimdi AppA çalıyor
        t.audible = [t.a]
        t.a.playing = true

        // 1. Basış: Çalan AppA'yı duraklatır
        XCTAssertTrue(t.press())
        XCTAssertFalse(t.a.playing, "ilk basış çalanı durdurur")
        XCTAssertFalse(t.b.playing, "diğeri henüz başlamadı")
        XCTAssertEqual(t.router.target?.displayName, "AppA")

        // Hızlı 2. basış: Diğer medyaya (AppB) geçer ve başlatır
        XCTAssertTrue(t.press())
        XCTAssertFalse(t.a.playing, "AppA duraklatılmış kalır")
        XCTAssertTrue(t.b.playing, "hızlı 2. basış diğer medyayı (AppB) başlatır")
        XCTAssertEqual(t.router.target?.displayName, "AppB")
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

    func testExternalPauseRecognizedAndResumedOnKeyPress() {
        let t = Bench(); t.audible = [t.a]
        // Önce ses başladı
        t.router.handleAudioActivity(pid: 1000, isRunning: true)
        t.router.queue.sync {}
        XCTAssertEqual(t.router.sources.count, 1)
        XCTAssertTrue(t.router.sources[0].isPlaying)

        // Kullanıcı tarayıcıda space'e veya video içi butona basıp durdurdu (dış durdurma)
        t.a.playing = false
        t.audible = []
        t.router.handleAudioActivity(pid: 1000, isRunning: false)
        t.router.queue.sync {}

        XCTAssertEqual(t.router.sources.count, 1)
        XCTAssertFalse(t.router.sources[0].isPlaying, "dışarıdan durdurulan kaynak widget'ta duraklatılmış görünür")
        XCTAssertTrue(t.router.sources[0].isTarget, "dışarıdan durdurulan kaynak hedef olarak korunur")

        // Kullanıcı klavyedeki medya tuşuna bastığında doğrudan bu kaynak sürdürülür
        XCTAssertTrue(t.press())
        t.settle()
        XCTAssertTrue(t.a.playing, "tuş duraklatılmış kaynağı sürdürür")
        XCTAssertEqual(t.a.commands.last, "resume")
    }

    func testPausedSourceInCoreAudioRecognizedWithoutPlayingState() {
        let t = Bench()
        t.a.playing = false // Tarayıcıda video durdurulmuş
        t.audible = [t.a]   // Core Audio kaydı henüz açık
        XCTAssertTrue(t.press())
        t.settle()
        XCTAssertEqual(t.router.sources.map { $0.adapter.displayName }, ["AppA"])
        XCTAssertTrue(t.a.playing, "Core Audio'da durmuş olan kaynak listeye alınıp sürdürülür")
        XCTAssertEqual(t.a.commands.last, "resume")
    }

    func testDiscoverPausedSourceResumesInsteadOfPassthroughToMusic() {
        let t = Bench()
        t.audible = []
        t.a.playing = false
        t.a.pausedMedia = true // Brave'de duraklatılmış YouTube sekmesi var
        XCTAssertTrue(t.press(), "duraklatılmış medyası olan açık adapter tespit edilip sürdürülür")
        t.settle()
        XCTAssertEqual(t.router.sources.map { $0.adapter.displayName }, ["AppA"])
        XCTAssertTrue(t.a.playing)
        XCTAssertEqual(t.a.commands.last, "resume")
        XCTAssertEqual(t.launches, [], "Spotify/Music başlatılmaz")
    }
}
