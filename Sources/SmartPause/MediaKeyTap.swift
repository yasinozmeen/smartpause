import Foundation
import AppKit

/// CGEventTap ile media tuşlarını yakalar. Accessibility izni gerekir.
/// handler `true` dönerse tuş yutulur, `false` dönerse sisteme aynen bırakılır (passthrough).
final class MediaKeyTap {
    static let NX_KEYTYPE_PLAY = 16, NX_KEYTYPE_NEXT = 17, NX_KEYTYPE_PREVIOUS = 18, NX_KEYTYPE_FAST = 19, NX_KEYTYPE_REWIND = 20
    private var tap: CFMachPort?
    private let handler: (_ keyCode: Int) -> Bool

    init(handler: @escaping (_ keyCode: Int) -> Bool) { self.handler = handler }

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

    private var swallowKeyUp = false

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("[tap] DEVRE DIŞI (%d) → yeniden etkinleştiriliyor", type.rawValue)
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14, let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = Int((ns.data1 & 0xFFFF0000) >> 16)
        let keyDown = ((ns.data1 & 0xFF00) >> 8) == 0x0A
        NSLog("[tap] media key %d %@", keyCode, keyDown ? "DOWN" : "UP")
        if keyDown {
            swallowKeyUp = handler(keyCode)
            return swallowKeyUp ? nil : Unmanaged.passUnretained(event)
        } else {
            let s = swallowKeyUp; swallowKeyUp = false
            return s ? nil : Unmanaged.passUnretained(event)
        }
    }
}
