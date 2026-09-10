// Spike B: CGEventTap ile play/pause yakalama + passthrough. Accessibility izni gerekir.
import Darwin
import Foundation
import CoreGraphics
import AppKit
setvbuf(stdout, nil, _IONBF, 0)

let NX_SYSDEFINED: CGEventType = CGEventType(rawValue: 14)!
let NX_KEYTYPE_PLAY = 16, NX_KEYTYPE_NEXT = 17, NX_KEYTYPE_PREVIOUS = 18, NX_KEYTYPE_FAST = 19, NX_KEYTYPE_REWIND = 20

let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
print("Accessibility izni: \(trusted ? "VAR" : "YOK — Sistem Ayarları > Gizlilik > Erişilebilirlik")")

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        print("tap devre dışı kaldı (\(type.rawValue)), yeniden etkinleştirilecek"); return Unmanaged.passUnretained(event)
    }
    guard type == NX_SYSDEFINED, let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else {
        return Unmanaged.passUnretained(event)
    }
    let data = ns.data1
    let keyCode = Int((data & 0xFFFF0000) >> 16)
    let keyDown = ((data & 0xFF00) >> 8) == 0x0A
    guard keyCode == NX_KEYTYPE_PLAY else { return Unmanaged.passUnretained(event) }
    if keyDown {
        print("▶︎ PLAY/PAUSE basıldı — burada hedef seçilip adapter çağrılacak")
    }
    // Karar: hedef bulunduysa nil döndür (tuşu yut), bulunamadıysa passthrough.
    let swallow = CommandLine.arguments.contains("--swallow")
    return swallow ? nil : Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                  eventsOfInterest: CGEventMask(1 << NX_SYSDEFINED.rawValue), callback: callback, userInfo: nil)
else { print("tap oluşturulamadı (izin yok?)"); exit(1) }
let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("Dinleniyor. Play/pause tuşuna bas (Ctrl+C ile çık). --swallow ile tuş sisteme gitmez.")
CFRunLoopRun()
