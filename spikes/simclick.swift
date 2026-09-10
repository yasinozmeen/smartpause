import AppKit
// Kullanım: simclick x y [clickCount]  — gerçek CGEvent fare tıklaması (System Events "click at" AX tabanlı, panelimizi görmüyor)
let a = CommandLine.arguments
let x = Double(a[1])!, y = Double(a[2])!, n = a.count > 3 ? Int(a[3])! : 1
let p = CGPoint(x: x, y: y)
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(60000)
for i in 1...n {
    let d = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)!
    d.setIntegerValueField(.mouseEventClickState, value: Int64(i)); d.post(tap: .cghidEventTap)
    usleep(40000)
    let u = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)!
    u.setIntegerValueField(.mouseEventClickState, value: Int64(i)); u.post(tap: .cghidEventTap)
    usleep(80000)
}
usleep(200000)
