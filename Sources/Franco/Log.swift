import Foundation

/// Tiny file logger: ~/Library/Application Support/Franco/franco.log
enum Log {
    private static let url = ResourceLocator.supportDir.appendingPathComponent("franco.log")
    private static let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f }()
    static func info(_ msg: String) {
        let line = "\(fmt.string(from: Date())) \(msg)\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
        else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }
}
