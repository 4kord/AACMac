import Foundation
@testable import AACCore

final class StubProbe: ProcessProbe {
    var running: [String: Int] = [:]
    func count(_ pattern: String) -> Int { running[pattern] ?? 0 }
}

final class StubRunner: CommandRunning {
    var status: Int32 = 0
    var error: Error?
    var onRun: ((URL, [String]) throws -> Void)?
    private(set) var calls: [[String]] = []

    func run(_ exe: URL, _ args: [String], env: [String: String], cwd: URL?) async throws -> CommandResult {
        calls.append([exe.lastPathComponent] + args)
        if let error { throw error }
        try onRun?(exe, args)
        return CommandResult(status: status, output: "")
    }

    func spawn(_ exe: URL, _ args: [String], env: [String: String], cwd: URL?, log: URL?) throws -> Process {
        calls.append([exe.lastPathComponent] + args)
        return Process()
    }
}

final class StepRecorder: SetupStepPerforming {
    var done: [SetupStep] = []
    func perform(_ step: SetupStep) async throws { done.append(step) }
}

enum Fixture {
    static func healthyInstallation() throws -> (AppPaths, BundleResources) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = AppPaths(root: root, logs: root.appendingPathComponent("logs"))

        let resDir = root.appendingPathComponent("res")
        try fm.createDirectory(at: resDir, withIntermediateDirectories: true)
        try Data("fix-v2".utf8).write(to: resDir.appendingPathComponent("dwmapi.dll"))
        try #"{"revision":"r1","releaseTag":"t","asset":"a","sha256":"s","sizeBytes":0}"#
            .write(to: resDir.appendingPathComponent("lock.json"), atomically: true, encoding: .utf8)
        let res = BundleResources(runtimeTarball: resDir, runtimeLock: resDir.appendingPathComponent("lock.json"),
                                  dwmapi: resDir.appendingPathComponent("dwmapi.dll"), sevenZip: resDir)

        try fm.createDirectory(at: paths.runtime, withIntermediateDirectories: true)
        try "r1\n".write(to: paths.runtimeRevisionFile, atomically: true, encoding: .utf8)
        try fm.createDirectory(at: paths.gameDir, withIntermediateDirectories: true)
        try Data("exe".utf8).write(to: paths.launcherExe)
        try Data("fix-v2".utf8).write(to: paths.installedDwmapi)
        try fm.createDirectory(at: paths.webView2Dir, withIntermediateDirectories: true)
        try Data().write(to: paths.webView2Dir.appendingPathComponent("msedgewebview2.exe"))
        try fm.createDirectory(at: paths.syswow64, withIntermediateDirectories: true)
        try Data().write(to: paths.syswow64.appendingPathComponent("mtld3d.dll"))
        try "[Software\\\\ArcheAgeClassicMac] 1\n\"FixesVersion\"=dword:\(String(format: "%08x", RegistryFixes.version))\n"
            .write(to: paths.prefix.appendingPathComponent("user.reg"), atomically: true, encoding: .utf8)
        try fm.createDirectory(at: paths.driveC.appendingPathComponent("users/player/Documents/AAClassic"),
                               withIntermediateDirectories: true)

        var state = SetupState()
        state.completed = SetupStep.allCases
        try state.save(to: paths.stateFile)
        return (paths, res)
    }
}
