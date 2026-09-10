import Foundation
import AppKit

/// CGEventTap ile media tuşlarını yakalar. Accessibility izni gerekir.
/// Desen: tuş ANINDA yutulur, karar ana kuyrukta verilir (AppleScript sorguları callback'i kilitlemesin diye —
/// aksi halde macOS tap'i zaman aşımıyla kapatıyor, ölçüldü). Karar "passthrough" ise tuş sisteme yeniden enjekte edilir;
/// enjekte edilen olay `marker` ile işaretlenir ve tap onu dokunmadan geçirir.
final class MediaKeyTap {
    static let NX_KEYTYPE_PLAY = 16, NX_KEYTYPE_NEXT = 17, NX_KEYTYPE_PREVIOUS = 18, NX_KEYTYPE_FAST = 19, NX_KEYTYPE_REWIND = 20
    private static let marker: Int64 = 0x534D5041   // "SMPA"
    private var tap: CFMachPort?
    /// `keyCode` için karar ver; `false` dönerse tuş sisteme yeniden gönderilir.
    private let handler: (_ keyCode: Int) -> Bool

    init(handler: @escaping (_ keyCode: Int) -> Bool) { self.handler = handler }

    /// Tuşu sisteme yeniden gönder (down + up), işaretli.
    static func reinject(keyCode: Int) {
        func post(_ down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = (keyCode << 16) | ((down ? 0xA : 0xB) << 8)
            guard let ev = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)?.cgEvent else { return }
            ev.setIntegerValueField(.eventSourceUserData, value: marker)
            ev.post(tap: .cghidEventTap)
        }
        post(true); post(false)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }
    static func requestTrust() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let sysDefined = CGEventType(rawValue: 14)! // NX_SYSDEFINED
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: CGEventMask(1 << sysDefined.rawValue),
                                        callback: { proxy, type, event, info in
            let me = Unmanaged<MediaKeyTap>.fromOpaque(info!).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }, userInfo: info) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false); CFMachPortInvalidate(t) }
        tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Log.write("[tap] DEVRE DIŞI (\(type.rawValue)) → yeniden etkinleştiriliyor")
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
        guard let ns = NSEvent(cgEvent: event) else { Log.write("[tap] UYARI: NSEvent dönüşümü başarısız, olay geçirildi"); return Unmanaged.passUnretained(event) }
        guard ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return Unmanaged.passUnretained(event) }  // bizim enjekte ettiğimiz
        let keyCode = Int((ns.data1 & 0xFFFF0000) >> 16)
        let keyDown = ((ns.data1 & 0xFF00) >> 8) == 0x0A
        guard (16...20).contains(keyCode) else { return Unmanaged.passUnretained(event) }
        Log.write("[tap] media key \(keyCode) \(keyDown ? "DOWN" : "UP")")
        if keyDown {
            let h = handler
            DispatchQueue.main.async { if !h(keyCode) { Self.reinject(keyCode: keyCode) } }
        }
        return nil   // down da up da yutulur; passthrough gerekiyorsa reinject eder
    }
}
