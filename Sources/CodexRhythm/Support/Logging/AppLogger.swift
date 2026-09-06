import Foundation

enum AppLogger {
    static let logFileURL = URL(
        fileURLWithPath: "\(NSHomeDirectory())/Library/Logs/CodexRhythm.debug.log"
    )

    static func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path),
           let handle = try? FileHandle(forWritingTo: logFileURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: logFileURL)
        }
    }
}
