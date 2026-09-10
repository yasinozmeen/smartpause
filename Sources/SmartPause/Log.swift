import Foundation

/// Basit dosya logu: ~/Library/Logs/SmartPause.log. Teşhis ve hata bildirimi için.
enum Log {
    private static let handle: FileHandle? = {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/SmartPause.log")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        let h = try? FileHandle(forWritingTo: url); h?.seekToEndOfFile(); return h
    }()
    private static let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f }()
    private static let q = DispatchQueue(label: "smartpause.log")
    static func write(_ s: String) {
        let line = "\(fmt.string(from: Date())) \(s)\n"
        q.async { handle?.write(line.data(using: .utf8)!) }
    }
}
