import Foundation

public enum PreferencesError: Error, Equatable {
    case launcherRunning
    case noGameSettingsFolder
}

public struct Preferences {
    // no .launcher/.gameSettings: repair never touches the game or player settings
    public static let repairSteps: [SetupStep] = [.runtime, .webView2, .directX, .mtld3d, .registry]

    let paths: AppPaths
    let runner: CommandRunning
    let probe: ProcessProbe

    public init(paths: AppPaths, runner: CommandRunning = ProcessRunner(), probe: ProcessProbe = PgrepProbe()) {
        self.paths = paths
        self.runner = runner
        self.probe = probe
    }

    public var options: LaunchOptions { SetupState.load(from: paths.stateFile).options }

    public func setRenderer(_ renderer: Renderer) async throws {
        try update { $0.renderer = renderer }
        try await Wine(paths: paths, options: options, runner: runner)
            .importRegistry(RegistryFixes.reg(renderer: renderer))
    }

    public func setX87(_ on: Bool) throws { try update { $0.x87 = on } }
    public func setMetalHUD(_ on: Bool) throws { try update { $0.metalHUD = on } }

    public func setWindowed(_ windowed: Bool) throws {
        try update { $0.windowed = windowed }
        try editGameSettings([("r_Fullscreen", windowed ? "0" : "1")])
    }

    public func resetGameSettings(screen: (Int, Int)) throws {
        try update { $0.windowed = true }
        try editGameSettings(GameSettings.defaults(width: screen.0, height: screen.1))
    }

    public func repair(engine: SetupEngine, resources: BundleResources) async throws {
        // can't swap the runtime under a running launcher or game
        if probe.count(LauncherSupervisor.launcherPattern) > 0 || probe.count(LauncherSupervisor.gamePattern) > 0 {
            throw PreferencesError.launcherRunning
        }
        try engine.reset(Self.repairSteps)
        try await engine.runPending()
        try Installation.installDwmapi(paths: paths, resources: resources)
    }

    private func update(_ change: (inout LaunchOptions) -> Void) throws {
        var state = SetupState.load(from: paths.stateFile)
        change(&state.options)
        try state.save(to: paths.stateFile)
    }

    private func editGameSettings(_ settings: [(key: String, value: String)]) throws {
        guard let docs = paths.documentsDir() else { throw PreferencesError.noGameSettingsFolder }
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let cfg = docs.appendingPathComponent("system.cfg")
        let text = GameSettings.merge((try? String(contentsOf: cfg)) ?? "", settings, overwrite: true)
        try text.write(to: cfg, atomically: true, encoding: .utf8)
    }
}
