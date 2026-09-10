import Foundation
import CoreAudio
import AppKit

/// Hangi process'in ne zaman ses çıkarmaya BAŞLADIĞINI olay tabanlı izler.
/// Polling yok: Core Audio, process listesi ya da bir process'in çıkış durumu değişince haber verir.
/// Amaç: çift kaynak modunda "en son başlayan" birincil hedef adayıdır (öndeki uygulamadan sonra gelen eşitlik bozucu).
/// Ölçüldü (Spike D, 2026-09-10): `kAudioProcessPropertyIsRunningOutput` için bildirim GELMİYOR; `kAudioProcessPropertyIsRunning`
/// ('pir?') geliyor ama uygulama duraklatınca çoğu zaman sesi kapatmadığı için seyrek. Bu yüzden yaklaşık bir sinyaldir:
/// bildirim + her tuş basışında görülen durum birleştirilir. Polling yok.
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

    /// Tuş basışında görülen anlık durumla birleştir: ilk kez çalarken görülen kaydedilir, artık çalmayan silinir.
    func observe(playing pids: Set<pid_t>) {
        lock.lock(); defer { lock.unlock() }
        for pid in pids where startedAt[pid] == nil { startedAt[pid] = Date() }
        for pid in startedAt.keys where !pids.contains(pid) { startedAt[pid] = nil }
    }

    private func syncProcessList() {
        var a = addr(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr else { return }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return }
        Log.write("[tracker] process listesi: \(ids.count) nesne, izlenen \(watched.count)")
        for id in ids where !watched.contains(id) {
            watched.insert(id)
            var ra = addr(kAudioProcessPropertyIsRunning)   // 'piro' bildirim üretmiyor, 'pir?' üretiyor
            let st = AudioObjectAddPropertyListenerBlock(id, &ra, queue) { [weak self] _, _ in self?.update(id) }
            if st != noErr { Log.write("[tracker] dinleyici eklenemedi id=\(id) hata=\(st)") }
            update(id)
        }
    }

    private func update(_ id: AudioObjectID) {
        var pa = addr(kAudioProcessPropertyPID); var ps = UInt32(MemoryLayout<Int32>.size); var pid: Int32 = 0
        guard AudioObjectGetPropertyData(id, &pa, 0, nil, &ps, &pid) == noErr else { return }
        var ra = addr(kAudioProcessPropertyIsRunningOutput); var rs = UInt32(MemoryLayout<UInt32>.size); var running: UInt32 = 0
        guard AudioObjectGetPropertyData(id, &ra, 0, nil, &rs, &running) == noErr else { return }
        lock.lock(); defer { lock.unlock() }
        if running != 0 { if startedAt[pid] == nil { startedAt[pid] = Date(); Log.write("[tracker] pid \(pid) ses başladı") } } else { if startedAt[pid] != nil { Log.write("[tracker] pid \(pid) ses durdu") }; startedAt[pid] = nil }
    }
}

/// Kullanıcı niyeti sinyali: uygulamalar en son ne zaman öne getirildi. NSWorkspace bildirimi, polling yok.
final class ActivationTracker {
    static let shared = ActivationTracker()
    private var lastActivated: [pid_t: Date] = [:]
    private var token: NSObjectProtocol?
    func start() {
        if let f = NSWorkspace.shared.frontmostApplication { lastActivated[f.processIdentifier] = Date() }
        token = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.lastActivated[app.processIdentifier] = Date() }
        }
    }
    func lastActivation(pid: pid_t) -> Date? { lastActivated[pid] }
}
