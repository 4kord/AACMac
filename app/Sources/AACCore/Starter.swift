import Foundation

public enum StartPlan: Equatable {
    // don't touch the runtime under a running launcher or game
    case alreadyRunning
    case setup
    case repair(steps: [SetupStep], restoreDwmapi: Bool)
    case launch
}

public struct Starter {
    let paths: AppPaths
    let resources: BundleResources
    let probe: ProcessProbe

    public init(paths: AppPaths, resources: BundleResources, probe: ProcessProbe) {
        self.paths = paths
        self.resources = resources
        self.probe = probe
    }

    public func plan() throws -> StartPlan {
        if probe.count(LauncherSupervisor.launcherPattern) > 0 || probe.count(LauncherSupervisor.gamePattern) > 0 {
            return .alreadyRunning
        }
        if !SetupState.load(from: paths.stateFile).isComplete { return .setup }
        let issues = try QuickCheck(paths: paths, resources: resources).issues()
        if issues.isEmpty { return .launch }
        return .repair(steps: QuickCheck.stepsToRedo(for: issues),
                       restoreDwmapi: issues.contains(.dwmapiMissingOrChanged))
    }

    public func prepare(_ plan: StartPlan, engine: SetupEngine) async throws {
        switch plan {
        case .alreadyRunning, .launch:
            return
        case .setup:
            try await engine.runPending()
        case let .repair(steps, restoreDwmapi):
            try engine.reset(steps)
            try await engine.runPending()
            if restoreDwmapi { try Installation.installDwmapi(paths: paths, resources: resources) }
        }
    }
}

extension SetupStep {
    public var title: String {
        switch self {
        case .runtime: return "Installing the Wine runtime"
        case .prefix: return "Creating the Windows environment"
        case .webView2: return "Downloading Microsoft WebView2"
        case .directX: return "Downloading Microsoft DirectX components"
        case .mtld3d: return "Installing the Metal renderer"
        case .registry: return "Applying compatibility settings"
        case .launcher: return "Installing the official ArcheAge Classic launcher"
        case .gameSettings: return "Writing default game settings"
        }
    }
}
