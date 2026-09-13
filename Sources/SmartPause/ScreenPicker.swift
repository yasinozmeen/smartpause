import AppKit

extension NSScreen {
    /// Farenin bulunduğu ekran (Yasin, 2026-09-13: çift ekranda widget hep Mac ekranına geliyordu).
    /// `NSRect.contains` üst ve sağ kenarı dışarıda sayar; fare menü çubuğu hizasına (y = maxY) dayanınca hiçbir ekran
    /// eşleşmiyor, kod `NSScreen.main`'e düşüyordu. Etkinleştirmeyen bir menü bar uygulamasında `main` odaktaki pencerenin
    /// ekranıdır, farenin değil. Burada kenarlar dahil sayılır; yine eşleşme yoksa fareye en yakın ekran seçilir.
    static var underMouse: NSScreen {
        let m = NSEvent.mouseLocation
        let screens = NSScreen.screens
        if let s = screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(m) }) { return s }
        func distance(_ r: NSRect) -> CGFloat {
            let dx = max(r.minX - m.x, 0, m.x - r.maxX), dy = max(r.minY - m.y, 0, m.y - r.maxY)
            return dx * dx + dy * dy
        }
        return screens.min { distance($0.frame) < distance($1.frame) } ?? NSScreen.main ?? screens[0]
    }
}
