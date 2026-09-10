import Foundation
import CoreAudio
import AppKit

/// Core Audio (public API, macOS 14.2+) ile şu an fiilen ses ÇIKARAN process'leri bulur.
/// Ses kaydı izni gerekmez. Sadece tuşa basıldığında çağrılır (~14 ms).
struct AudioProcess {
    let pid: pid_t
    let bundleID: String
    let responsiblePID: pid_t
    let responsibleBundleID: String
    let name: String
}

enum AudioDetector {
    private static func addr(_ sel: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private static func get<T>(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector, _ zero: T) -> T? {
        var a = addr(sel); var size = UInt32(MemoryLayout<T>.size); var v = zero
        return AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v) == noErr ? v : nil
    }
    private static func getString(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var a = addr(sel); var size = UInt32(MemoryLayout<CFString?>.size); var v: Unmanaged<CFString>? = nil
        guard AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v) == noErr else { return nil }
        return v?.takeRetainedValue() as String?
    }

    /// Şu an ses çıkaran process'ler.
    static func runningOutputProcesses() -> [AudioProcess] {
        var a = addr(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard (get(id, kAudioProcessPropertyIsRunningOutput, UInt32(0)) ?? 0) != 0,
                  let pid = get(id, kAudioProcessPropertyPID, Int32(0)) else { return nil }
            let bundle = getString(id, kAudioProcessPropertyBundleID) ?? ""
            let rpid = ResponsibleProcess.pid(for: pid)
            let rbundle = NSRunningApplication(processIdentifier: rpid)?.bundleIdentifier ?? bundle
            let name = NSRunningApplication(processIdentifier: rpid)?.localizedName
                ?? NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
            return AudioProcess(pid: pid, bundleID: bundle, responsiblePID: rpid, responsibleBundleID: rbundle, name: name)
        }
    }
}

/// Helper process (tarayıcı GPU/renderer, WebKit.GPU) → sorumlu ana uygulama.
/// `responsibility_get_pid_responsible_for_pid` belgelenmemiş ama TCC'nin kendisinin kullandığı bir libSystem fonksiyonudur.
/// Bulunamazsa pid'in kendisi döner (fail-safe). Private API bu tek noktada izole edilmiştir.
enum ResponsibleProcess {
    private typealias Fn = @convention(c) (pid_t) -> pid_t
    private static let fn: Fn? = {
        guard let h = dlopen(nil, RTLD_NOW), let sym = dlsym(h, "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(sym, to: Fn.self)
    }()
    static func pid(for pid: pid_t) -> pid_t {
        guard let fn else { return pid }
        let r = fn(pid)
        return r > 0 ? r : pid
    }
}
