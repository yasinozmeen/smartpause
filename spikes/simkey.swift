import AppKit
// Play/pause media key'i sisteme gönder (down + up)
func post(_ down: Bool) {
    let flags: NSEvent.ModifierFlags = down ? [.init(rawValue: 0xa00)] : [.init(rawValue: 0xb00)]
    let data1 = (16 << 16) | ((down ? 0xA : 0xB) << 8)
    let ev = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)!
    ev.cgEvent?.post(tap: .cghidEventTap)
}
post(true); post(false); print("simüle edildi")
