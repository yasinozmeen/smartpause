import AppKit
// Play/pause media key'i sisteme gönder (down + up)
func post(_ down: Bool, _ code: Int) {
    let flags: NSEvent.ModifierFlags = down ? [.init(rawValue: 0xa00)] : [.init(rawValue: 0xb00)]
    let data1 = (code << 16) | ((down ? 0xA : 0xB) << 8)
    let ev = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)!
    ev.cgEvent?.post(tap: .cghidEventTap)
}
let code = Int(CommandLine.arguments.dropFirst().first ?? "16") ?? 16
post(true, code); usleep(30000); post(false, code); usleep(300000); print("simüle edildi")
