// Spike D: kAudioProcessPropertyIsRunningOutput dinleyicisi gerçekten tetikleniyor mu?
import Foundation
import CoreAudio
setvbuf(stdout, nil, _IONBF, 0)
func fourCC(_ v: UInt32) -> String {
    let b = [UInt8((v >> 24) & 255), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)]
    return String(bytes: b, encoding: .ascii) ?? "?"
}
func addr(_ s: AudioObjectPropertySelector) -> AudioObjectPropertyAddress { .init(mSelector: s, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain) }
var a = addr(kAudioHardwarePropertyProcessObjectList); var size: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size)
var ids = [AudioObjectID](repeating: 0, count: Int(size)/4)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids)
let q = DispatchQueue(label: "l")
for id in ids {
    var pa = addr(kAudioProcessPropertyPID); var ps = UInt32(4); var pid: Int32 = 0
    AudioObjectGetPropertyData(id, &pa, 0, nil, &ps, &pid)
    var ra = addr(kAudioProcessPropertyIsRunningOutput)
    let st = AudioObjectAddPropertyListenerBlock(id, &ra, q) { n, addrs in
        var rs = UInt32(4); var r: UInt32 = 0; var ra2 = addr(kAudioProcessPropertyIsRunningOutput)
        AudioObjectGetPropertyData(id, &ra2, 0, nil, &rs, &r)
        let names = (0..<Int(n)).map { fourCC(addrs[$0].mSelector) }
        print("DEĞİŞTİ pid=\(pid) running=\(r) adres: \(names)")
    }
    // Ayrıca genel "IsRunning" ve tüm seçiciler için de dinle (teşhis)
    var wa = addr(kAudioObjectPropertySelectorWildcard)
    AudioObjectAddPropertyListenerBlock(id, &wa, q) { n, addrs in
        let names = (0..<Int(n)).map { fourCC(addrs[$0].mSelector) }
        print("wildcard pid=\(pid): \(names)")
    }
    if st != noErr { print("hata \(st) pid \(pid)") }
}
print("dinleniyor (\(ids.count) process)…")
CFRunLoopRun()
