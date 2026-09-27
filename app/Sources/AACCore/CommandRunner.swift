import Foundation

public struct CommandResult: Equatable {
    public let status: Int32
    public let output: String
}

public protocol CommandRunning {
    func run(_ exe: URL, _ args: [String], env: [String: String], cwd: URL?) async throws -> CommandResult
    func spawn(_ exe: URL, _ args: [String], env: [String: String], cwd: URL?, log: URL?) throws -> Process
}

public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ exe: URL, _ args: [String], env: [String: String], cwd: URL?) async throws -> CommandResult {
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        p.environment = ProcessInfo.processInfo.environment.merging(env) { $1 }
        if let cwd { p.currentDirectoryURL = cwd }
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return CommandResult(status: p.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    public func spawn(_ exe: URL, _ args: [String], env: [String: String], cwd: URL?, log: URL?) throws -> Process {
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        p.environment = ProcessInfo.processInfo.environment.merging(env) { $1 }
        if let cwd { p.currentDirectoryURL = cwd }
        if let log {
            FileManager.default.createFile(atPath: log.path, contents: nil)
            let h = try FileHandle(forWritingTo: log)
            h.seekToEndOfFile()
            p.standardOutput = h
            p.standardError = h
        } else {
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
        }
        try p.run()
        return p
    }
}
