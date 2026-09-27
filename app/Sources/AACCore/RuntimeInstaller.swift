import Foundation

public struct RuntimeLock: Codable, Equatable {
    public let revision: String
    public let releaseTag: String
    public let asset: String
    public let sha256: String
    public let sizeBytes: Int64

    public init(revision: String, releaseTag: String, asset: String, sha256: String, sizeBytes: Int64) {
        self.revision = revision; self.releaseTag = releaseTag; self.asset = asset
        self.sha256 = sha256; self.sizeBytes = sizeBytes
    }

    public static func load(from url: URL) throws -> RuntimeLock {
        try JSONDecoder().decode(RuntimeLock.self, from: Data(contentsOf: url))
    }
}

public enum InstallError: Error, Equatable {
    case runtimeHashMismatch
    case commandFailed(String)
}

public struct RuntimeInstaller {
    let paths: AppPaths
    let runner: CommandRunning

    public init(paths: AppPaths, runner: CommandRunning) {
        self.paths = paths
        self.runner = runner
    }

    public func installedRevision() -> String? {
        guard let s = try? String(contentsOf: paths.runtimeRevisionFile) else { return nil }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func install(tarball: URL, lock: RuntimeLock) async throws {
        guard try FileHash.sha256(of: tarball) == lock.sha256 else { throw InstallError.runtimeHashMismatch }
        let fm = FileManager.default
        let staging = paths.root.appendingPathComponent("runtime.staging")
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        let r = try await runner.run(URL(fileURLWithPath: "/usr/bin/tar"),
                                     ["-xJf", tarball.path, "-C", staging.path], env: [:], cwd: nil)
        guard r.status == 0 else { throw InstallError.commandFailed("tar: \(r.output.suffix(300))") }
        try? fm.removeItem(at: paths.runtime)
        try fm.moveItem(at: staging.appendingPathComponent("runtime"), to: paths.runtime)
        try? fm.removeItem(at: staging)
        _ = try await runner.run(URL(fileURLWithPath: "/usr/bin/xattr"), ["-cr", paths.runtime.path], env: [:], cwd: nil)
    }
}
