import Foundation

public enum AppLog {
    public static func append(_ line: String, paths: AppPaths) {
        let fm = FileManager.default
        try? fm.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        let file = paths.logs.appendingPathComponent("starter.log")
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(line)\n".utf8)
        if let h = try? FileHandle(forWritingTo: file) {
            h.seekToEndOfFile()
            h.write(data)
            try? h.close()
        } else {
            try? data.write(to: file)
        }
    }
}
