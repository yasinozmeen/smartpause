import AppKit
import ApplicationServices

/// macOS bildirim banner'larının ekrandaki yerini okur (Erişilebilirlik API'si; izin zaten var).
/// Ölçüldü (2026-09-11): Bildirim Merkezi tek tam-ekran pencere çizer, CGWindowList konum vermez; AX ağacında
/// `AXNotificationCenterBanner` alt-rolü gerçek çerçeveyi verir (ör. 1440,55 344×57, sol-üst orijin).
enum NotificationBanners {
    /// Ekranın sağ üstündeki banner'ların en alt kenarı, Cocoa koordinatında (sol-alt orijin). Banner yoksa nil.
    static func lowestEdge(on screen: NSScreen) -> CGFloat? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return nil }
        var frames: [CGRect] = []
        collect(AXUIElementCreateApplication(app.processIdentifier), depth: 0, into: &frames)
        // AX koordinatı: birincil ekranın sol üstü orijin. Cocoa'ya çevir.
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let bottoms = frames.compactMap { f -> CGFloat? in
            let cocoa = CGRect(x: f.minX, y: primaryTop - f.maxY, width: f.width, height: f.height)
            return screen.frame.intersects(cocoa) ? cocoa.minY : nil
        }
        return bottoms.min()
    }

    private static func collect(_ e: AXUIElement, depth: Int, into out: inout [CGRect]) {
        guard depth < 7 else { return }
        if subrole(e) == "AXNotificationCenterBanner" || subrole(e) == "AXNotificationCenterAlert", let f = frame(e), f.width > 0 { out.append(f); return }
        // Menü çubuğu altına inme (yüzlerce boş öğe).
        if role(e) == "AXMenuBar" { return }
        var kids: AnyObject?
        if AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &kids) == .success, let arr = kids as? [AXUIElement] {
            for k in arr { collect(k, depth: depth + 1, into: &out) }
        }
    }
    private static func role(_ e: AXUIElement) -> String? { var v: AnyObject?; AXUIElementCopyAttributeValue(e, kAXRoleAttribute as CFString, &v); return v as? String }
    private static func subrole(_ e: AXUIElement) -> String? { var v: AnyObject?; AXUIElementCopyAttributeValue(e, kAXSubroleAttribute as CFString, &v); return v as? String }
    private static func frame(_ e: AXUIElement) -> CGRect? {
        var p: AnyObject?, s: AnyObject?
        guard AXUIElementCopyAttributeValue(e, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(e, kAXSizeAttribute as CFString, &s) == .success else { return nil }
        var pt = CGPoint.zero, sz = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &pt); AXValueGetValue(s as! AXValue, .cgSize, &sz)
        return CGRect(origin: pt, size: sz)
    }
}
