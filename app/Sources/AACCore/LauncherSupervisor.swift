import Foundation

public protocol ProcessProbe {
    func count(_ pattern: String) -> Int
}

public struct PgrepProbe: ProcessProbe {
    public init() {}

    public func count(_ pattern: String) -> Int {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-f", pattern]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return 0 }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").count
    }
}

public enum LaunchOutcome: Equatable {
    case started
    case alreadyRunning
    case failed(attempts: Int)
}

// WebView2 sometimes dies right after start (Wine user_check_not_lock assertion); a restart fixes it
public final class LauncherSupervisor {
    public static let launcherPattern = "ArcheAge Classic Launcher.exe"
    public static let webViewPattern = "msedgewebview2.exe"
    public static let gamePattern = "bin32/archeage.exe"

    let probe: ProcessProbe
    let start: () throws -> Void
    let stop: () async -> Void
    let sleep: (Double) async -> Void
    let maxRestarts: Int
    let settle: Double

    public init(probe: ProcessProbe,
                start: @escaping () throws -> Void,
                stop: @escaping () async -> Void,
                sleep: @escaping (Double) async -> Void = { try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) },
                maxRestarts: Int = 2,
                settle: Double = 25) {
        self.probe = probe
        self.start = start
        self.stop = stop
        self.sleep = sleep
        self.maxRestarts = maxRestarts
        self.settle = settle
    }

    public var launcherRunning: Bool { probe.count(Self.launcherPattern) > 0 }
    public var gameRunning: Bool { probe.count(Self.gamePattern) > 0 }

    public func launch() async throws -> LaunchOutcome {
        // never stop a prefix the game runs in
        if launcherRunning || gameRunning { return .alreadyRunning }
        let attempts = maxRestarts + 1
        for _ in 0..<attempts {
            try start()
            await sleep(settle)
            if probe.count(Self.webViewPattern) > 0 { return .started }
            await stop()
        }
        return .failed(attempts: attempts)
    }
}
