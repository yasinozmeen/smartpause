import XCTest
@testable import SmartPause

final class L10nTests: XCTestCase {
    private func placeholders(_ s: String) -> [String] {
        var out: [String] = []; var it = s.makeIterator()
        while let c = it.next() { if c == "%", let n = it.next() { out.append(String(n)) } }
        return out
    }
    /// İngilizce ve Türkçe aynı sayıda ve sırada %@/%d taşımalı; her anahtarın Türkçesi olmalı.
    func testEveryKeyHasTurkishWithMatchingPlaceholders() {
        for (key, tr) in L.tr {
            XCTAssertEqual(placeholders(key.rawValue), placeholders(tr), "\(key) yer tutucuları uyuşmuyor")
        }
        let untranslated = allKeys.filter { L.tr[$0] == nil }
        XCTAssertTrue(untranslated.isEmpty, "Türkçesi eksik: \(untranslated)")
    }
    func testLanguageSwitchChangesText() {
        Settings.language = .en; XCTAssertEqual(L.ready.t, "Ready")
        Settings.language = .tr; XCTAssertEqual(L.ready.t, "Hazır")
        XCTAssertEqual(L.statusPlaying("X"), "X çalıyor")
        Settings.language = .en
    }
    /// L bir String enum; tüm case'ler kaynak dosyadan türetilir (CaseIterable eklemeden).
    private var allKeys: [L] {
        let src = try! String(contentsOfFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/SmartPause/L10n.swift").path, encoding: .utf8)
        return src.split(separator: "\n").compactMap { line -> L? in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("case "), let eq = t.range(of: " = \"") else { return nil }
            let raw = t[eq.upperBound...].dropLast().replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\n", with: "\n")
            return L(rawValue: raw)
        }
    }
}
