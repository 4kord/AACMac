import AACCore
import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case checking
        case needsRosetta
        case working(title: String, detail: String, step: Int, total: Int)
        case launching
        case running
        case failed(String)
    }

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var options = LaunchOptions()
    @Published private(set) var busy = false
    @Published var preferencesError: String?

    let paths = AppPaths.standard()
    let resources = BundleResources.main()
    private let probe = PgrepProbe()
    private var window: NSWindow?
    private var watching = false

    var preferences: Preferences { Preferences(paths: paths) }

    var statusLine: String {
        switch phase {
        case .checking: return "Checking installation…"
        case .needsRosetta: return "Rosetta 2 is required"
        case let .working(title, _, step, total): return "\(title) (\(step)/\(total))"
        case .launching: return "Starting the launcher…"
        case .running: return "Launcher running"
        case .failed: return "Needs attention"
        }
    }

    func start() {
        Task { await startFlow() }
    }

    func retry() {
        phase = .checking
        start()
    }

    private func startFlow() async {
        guard let resources else {
            return fail("The app is damaged: files inside it are missing. Download it again.")
        }
        options = preferences.options
        guard await Rosetta.isInstalled(runner: ProcessRunner()) else {
            phase = .needsRosetta
            return showWindow()
        }
        do {
            let starter = Starter(paths: paths, resources: resources, probe: probe)
            let plan = try starter.plan()
            AppLog.append("start plan: \(plan)", paths: paths)
            switch plan {
            case .alreadyRunning:
                return watchLauncher()
            case .setup, .repair:
                let title = plan == .setup ? "Setting up ArcheAge Classic" : "Repairing ArcheAge Classic"
                phase = .working(title: title, detail: "", step: 0, total: SetupStep.allCases.count)
                showWindow()
                let engine = SetupEngine(stateURL: paths.stateFile, performer: installationSteps(resources)) { step, i, n in
                    Task { @MainActor in
                        self.phase = .working(title: title, detail: step.title, step: i, total: n)
                        AppLog.append("step \(i)/\(n): \(step.rawValue)", paths: self.paths)
                    }
                }
                try await starter.prepare(plan, engine: engine)
            case .launch:
                break
            }
            try await launch()
        } catch {
            fail(UserMessage.text(for: error))
        }
    }

    private func installationSteps(_ resources: BundleResources) -> InstallationSteps {
        InstallationSteps(paths: paths, resources: resources, screenSize: Self.screenSize())
    }

    static func screenSize() -> (Int, Int) {
        let size = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        return (Int(size.width), Int(size.height))
    }

    private func launch() async throws {
        phase = .launching
        try FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        let wine = Wine(paths: paths, options: preferences.options, runner: ProcessRunner())
        let log = paths.logs.appendingPathComponent("wine.log")
        let supervisor = LauncherSupervisor(probe: probe,
                                            start: { _ = try wine.startLauncher(log: log) },
                                            stop: { await wine.killServer() })
        let outcome = try await supervisor.launch()
        AppLog.append("launch: \(outcome)", paths: paths)
        switch outcome {
        case .started, .alreadyRunning:
            window?.close()
            watchLauncher()
        case .failed(let attempts):
            fail("The launcher window did not come up after \(attempts) tries. Click Retry.")
        }
    }

    private func watchLauncher() {
        phase = .running
        guard !watching else { return }
        watching = true
        Task {
            var misses = 0
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let running = probe.count(LauncherSupervisor.launcherPattern) > 0
                    || probe.count(LauncherSupervisor.gamePattern) > 0
                misses = running ? 0 : misses + 1
                if misses >= 2 { NSApp.terminate(nil) }
            }
        }
    }

    private func fail(_ message: String) {
        AppLog.append("error: \(message)", paths: paths)
        phase = .failed(message)
        showWindow()
    }

    private func showWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
                             styleMask: [.titled], backing: .buffered, defer: false)
            w.title = "ArcheAge Classic"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SetupView().environmentObject(self))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func installRosetta() {
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(Rosetta.installCommand)\" with administrator privileges")?
            .executeAndReturnError(&error)
        if let error { AppLog.append("rosetta install: \(error)", paths: paths) }
        retry()
    }

    func setRenderer(_ r: Renderer) { perform { try await self.preferences.setRenderer(r) } }
    func setX87(_ on: Bool) { perform { try self.preferences.setX87(on) } }
    func setMetalHUD(_ on: Bool) { perform { try self.preferences.setMetalHUD(on) } }
    func setWindowed(_ on: Bool) { perform { try self.preferences.setWindowed(on) } }
    func resetGameSettings() { perform { try self.preferences.resetGameSettings(screen: Self.screenSize()) } }

    func repair() {
        guard let resources else { return }
        perform {
            let engine = SetupEngine(stateURL: self.paths.stateFile, performer: self.installationSteps(resources))
            try await self.preferences.repair(engine: engine, resources: resources)
        }
    }

    private func perform(_ op: @escaping () async throws -> Void) {
        busy = true
        preferencesError = nil
        Task {
            do { try await op() } catch { preferencesError = UserMessage.text(for: error) }
            options = preferences.options
            busy = false
        }
    }

    func openLogs() {
        try? FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        NSWorkspace.shared.open(paths.logs)
    }
}
