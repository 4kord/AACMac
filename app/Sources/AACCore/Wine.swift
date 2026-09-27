import Foundation

public struct Wine {
    let paths: AppPaths
    let options: LaunchOptions
    let runner: CommandRunning

    public init(paths: AppPaths, options: LaunchOptions, runner: CommandRunning) {
        self.paths = paths
        self.options = options
        self.runner = runner
    }

    var env: [String: String] { WineEnvironment.make(paths: paths, options: options) }

    @discardableResult
    public func run(_ args: [String], extraEnv: [String: String] = [:], cwd: URL? = nil) async throws -> CommandResult {
        let r = try await runner.run(paths.wine, args, env: env.merging(extraEnv) { $1 }, cwd: cwd)
        guard r.status == 0 else { throw InstallError.commandFailed("wine \(args.first ?? ""): \(r.output.suffix(300))") }
        return r
    }

    // no Mono/Gecko: their install prompt hangs wineboot
    public func boot() async throws {
        try await run(["wineboot", "-i"], extraEnv: ["WINEDLLOVERRIDES": "mscoree=;mshtml="])
        try await waitForServer()
    }

    public func importRegistry(_ text: String) async throws {
        let file = paths.driveC.appendingPathComponent("aac-fixes.reg")
        try text.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        try await run(["regedit", "/S", "C:\\aac-fixes.reg"])
        try await waitForServer()
    }

    public func waitForServer() async throws {
        _ = try await runner.run(paths.wineserver, ["-w"], env: env, cwd: nil)
    }

    public func killServer() async {
        _ = try? await runner.run(paths.wineserver, ["-k"], env: env, cwd: nil)
    }

    // the launcher installs the game into its working directory
    public func startLauncher(log: URL?) throws -> Process {
        try runner.spawn(paths.wine, [paths.launcherExe.lastPathComponent], env: env, cwd: paths.gameDir, log: log)
    }
}
