import XCTest
@testable import SmartPause

/// TIDAL adapter'ının menü mantığı (AX'siz kısım). Menü yapısı TIDAL 2.43.2'den: `app/main/menu/playbackMenu.js`.
final class TidalAdapterTests: XCTestCase {
    /// Playback menüsü (AX çocukları, ayraçlar boş başlık): Play|Pause, —, Previous, Next, —, Seek Back, Seek Forward, —, Repeat, Shuffle, —, Volume Up, Volume Down.
    private let en = ["Play", "", "Previous", "Next", "", "Seek back", "Seek forward", "", "Repeat", "Shuffle", "", "Volume up", "Volume down"]
    private let tr = ["Duraklat", "", "Önceki", "İleri", "", "Geri ara", "İleriye doğru arama", "", "Tekrarla", "Karıştır", "", "Sesi aç", "Sesi kıs"]

    func testFirstItemTitleIsTheRealPlayState() {
        XCTAssertEqual(TidalAdapter.playState(firstItemTitle: "Pause"), true, "çalarken ilk öğe Pause")
        XCTAssertEqual(TidalAdapter.playState(firstItemTitle: "Play"), false, "dururken ilk öğe Play")
        XCTAssertEqual(TidalAdapter.playState(firstItemTitle: "Duraklat"), true)
        XCTAssertEqual(TidalAdapter.playState(firstItemTitle: "Yürüt"), false)
        XCTAssertEqual(TidalAdapter.playState(firstItemTitle: "Пауза"), true)
        XCTAssertNil(TidalAdapter.playState(firstItemTitle: "About TIDAL"), "başka bir menü Playback sanılmamalı")
        XCTAssertNil(TidalAdapter.playState(firstItemTitle: ""))
        XCTAssertNil(TidalAdapter.playState(firstItemTitle: nil))
    }

    /// AX başlığı ayrışık (NFD) Unicode dönebilir; Swift String eşitliği kanonik olduğu için yine eşleşmeli.
    func testDecomposedTitleStillMatches() {
        XCTAssertEqual(TidalAdapter.playState(firstItemTitle: "Yu\u{0308}ru\u{0308}t"), false)
        XCTAssertEqual(TidalAdapter.itemIndex(in: ["Önceki"].map { $0.decomposedStringWithCanonicalMapping }, matching: TidalAdapter.previousTitles), 0)
    }

    /// Bir başlık iki kümede birden olsaydı durum ya da basılacak öğe yanlış seçilirdi.
    func testTitleSetsDoNotOverlap() {
        let sets = [TidalAdapter.playTitles, TidalAdapter.pauseTitles, TidalAdapter.nextTitles, TidalAdapter.previousTitles]
        for i in sets.indices { for j in sets.indices where i < j { XCTAssertTrue(sets[i].isDisjoint(with: sets[j]), "\(sets[i].intersection(sets[j]))") } }
    }

    func testNextAndPreviousFoundByTitle() {
        XCTAssertEqual(TidalAdapter.itemIndex(in: en, matching: TidalAdapter.nextTitles), 3)
        XCTAssertEqual(TidalAdapter.itemIndex(in: en, matching: TidalAdapter.previousTitles), 2)
        XCTAssertEqual(TidalAdapter.itemIndex(in: tr, matching: TidalAdapter.nextTitles), 3, "İleriye doğru arama (ileri sarma) sonraki parça sanılmamalı")
        XCTAssertEqual(TidalAdapter.itemIndex(in: tr, matching: TidalAdapter.previousTitles), 2)
        XCTAssertNil(TidalAdapter.itemIndex(in: ["File", "Edit"], matching: TidalAdapter.nextTitles))
    }

    /// Ses yardımcı process'lerden çıkar (TIDALPlayer, Chromium yardımcıları); hepsi TIDAL'a eşlenmeli.
    func testRegisteredAndOwnsHelperProcesses() {
        guard let tidal = Router.defaultAdapters.first(where: { $0.displayName == "TIDAL" }) else { return XCTFail("TIDAL kayıtlı değil") }
        for b in ["com.tidal.desktop", "com.tidal.desktop.player", "com.tidal.desktop.helper", "com.tidal.desktop.helper.Renderer"] {
            XCTAssertTrue(tidal.matches(bundleID: b), b)
        }
        XCTAssertFalse(tidal.matches(bundleID: "com.tidal.desktopbeta"))
    }
}
