import Foundation
import CoreAudio

/// Hangi process'in ne zaman ses çıkarmaya BAŞLADIĞINI olay tabanlı izler.
/// Polling yok: Core Audio, process listesi ya da bir process'in çıkış durumu değişince haber verir.
/// Amaç: çift kaynak modunda "en son başlayan" birincil hedef adayıdır.
final class AudioActivityTracker {
    static let shared = AudioActivityTracker()
    private var startedAt: [pid_t: Date] = [:]
    private var watched: Set<AudioObjectID> = []
    private let queue = DispatchQueue(label: "smartpause.audio-tracker")
    private let lock = NSLock()

    private func addr(_ sel: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    func start() {
        var a = addr(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, queue) { [weak self] _, _ in self?.syncProcessList() }
        queue.async { self.syncProcessList() }
    }

    func startTime(pid: pid_t) -> Date? { lock.lock(); defer { lock.unlock() }; return startedAt[pid] }

    private func syncProcessList() {
        var a = addr(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr else { return }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return }
        for id in ids where !watched.contains(id) {
            watched.insert(id)
            var ra = addr(kAudioProcessPropertyIsRunningOutput)
            AudioObjectAddPropertyListenerBlock(id, &ra, queue) { [weak self] _, _ in self?.update(id) }
            update(id)
        }
    }

    private func update(_ id: AudioObjectID) {
        var pa = addr(kAudioProcessPropertyPID); var ps = UInt32(MemoryLayout<Int32>.size); var pid: Int32 = 0
        guard AudioObjectGetPropertyData(id, &pa, 0, nil, &ps, &pid) == noErr else { return }
        var ra = addr(kAudioProcessPropertyIsRunningOutput); var rs = UInt32(MemoryLayout<UInt32>.size); var running: UInt32 = 0
        guard AudioObjectGetPropertyData(id, &ra, 0, nil, &rs, &running) == noErr else { return }
        lock.lock(); defer { lock.unlock() }
        if running != 0 { if startedAt[pid] == nil { startedAt[pid] = Date() } } else { startedAt[pid] = nil }
    }
}
