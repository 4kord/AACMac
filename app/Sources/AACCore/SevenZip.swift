import Foundation

public struct SevenZip {
    let binary: URL
    let runner: CommandRunning

    public init(binary: URL, runner: CommandRunning) {
        self.binary = binary
        self.runner = runner
    }

    public func extract(_ archive: URL, to dir: URL, patterns: [String] = [], flat: Bool = false) async throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let args = [flat ? "e" : "x", "-y", "-o\(dir.path)", archive.path] + patterns
        let r = try await runner.run(binary, args, env: [:], cwd: nil)
        guard r.status == 0 else { throw InstallError.commandFailed("7zz \(archive.lastPathComponent): \(r.output.suffix(300))") }
    }
}
