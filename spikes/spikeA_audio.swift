// Spike A: Core Audio ile şu an fiilen ses ÇIKARAN process'leri listele.
// Public API, macOS 14.2+. Tap kurmaya gerek yok; process object listesi + IsRunningOutput yeterli.
import Foundation
import CoreAudio
import AppKit

func prop(_ sel: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}

func getUInt32(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> UInt32? {
    var a = prop(sel); var size = UInt32(MemoryLayout<UInt32>.size); var v: UInt32 = 0
    return AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v) == noErr ? v : nil
}
func getInt32(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> Int32? {
    var a = prop(sel); var size = UInt32(MemoryLayout<Int32>.size); var v: Int32 = 0
    return AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v) == noErr ? v : nil
}
func getString(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
    var a = prop(sel); var size = UInt32(MemoryLayout<CFString?>.size); var v: Unmanaged<CFString>? = nil
    guard AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v) == noErr, let s = v?.takeRetainedValue() else { return nil }
    return s as String
}

struct AudioProc { let pid: pid_t; let bundle: String; let name: String; let running: Bool }

func activeProcesses() -> [AudioProc] {
    var a = prop(kAudioHardwarePropertyProcessObjectList)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.compactMap { id in
        guard let pid = getInt32(id, kAudioProcessPropertyPID) else { return nil }
        let running = (getUInt32(id, kAudioProcessPropertyIsRunningOutput) ?? 0) != 0
        let bundle = getString(id, kAudioProcessPropertyBundleID) ?? ""
        let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
        return AudioProc(pid: pid, bundle: bundle, name: name, running: running)
    }
}

let t0 = Date()
let procs = activeProcesses()
let dt = Date().timeIntervalSince(t0) * 1000
print(String(format: "Sorgu süresi: %.2f ms — %d audio process kayıtlı", dt, procs.count))
for p in procs.filter({ $0.running }) {
    print("▶︎ SES ÇIKARIYOR: \(p.name) [\(p.bundle)] pid=\(p.pid)")
}
if !procs.contains(where: { $0.running }) { print("(şu an ses çıkaran process yok)") }
if CommandLine.arguments.contains("--all") { procs.forEach { print("  \($0.running ? "▶︎" : "·") \($0.name) [\($0.bundle)]") } }
if CommandLine.arguments.contains("--bench") {
    let n = 200; let t = Date()
    for _ in 0..<n { _ = activeProcesses() }
    print(String(format: "Isınmış ortalama sorgu: %.3f ms", Date().timeIntervalSince(t) * 1000 / Double(n)))
}
