import XCTest
@testable import AACCore

final class PreferencesTests: XCTestCase {
    var paths: AppPaths!, res: BundleResources!, runner: StubRunner!, probe: StubProbe!

    var cfg: URL { paths.driveC.appendingPathComponent("users/player/Documents/AAClassic/system.cfg") }
    var prefs: Preferences { Preferences(paths: paths, runner: runner, probe: probe) }

    override func setUpWithError() throws {
        (paths, res) = try Fixture.healthyInstallation()
        runner = StubRunner()
        probe = StubProbe()
        try "locale = en_us\nr_fullscreen = 0\nr_driver = \"DX10\"\nr_width = 1000\n"
            .write(to: cfg, atomically: true, encoding: .utf8)
    }

    func testRendererSwitchSavesAndReimportsRegistry() async throws {
        var imported = ""
        let regFile = paths.driveC.appendingPathComponent("aac-fixes.reg")
        runner.onRun = { _, args in if args.first == "regedit" { imported = try String(contentsOf: regFile) } }
        try await prefs.setRenderer(.wined3d)
        XCTAssertEqual(prefs.options.renderer, .wined3d)
        XCTAssertTrue(imported.contains("\"d3d9\"=-"))
    }

    func testX87AndHUDChangeTheLaunchEnvironment() throws {
        try prefs.setX87(false)
        try prefs.setMetalHUD(true)
        let env = WineEnvironment.make(paths: paths, options: prefs.options)
        XCTAssertNil(env["ROSETTA_X87_PATH"])
        XCTAssertEqual(env["MTL_HUD_ENABLED"], "1")
    }

    func testFullscreenEditsOnlyThatLine() throws {
        try prefs.setWindowed(false)
        let text = try String(contentsOf: cfg)
        XCTAssertEqual(GameSettings.value(of: "r_Fullscreen", in: text), "1")
        XCTAssertEqual(GameSettings.value(of: "r_driver", in: text), "\"DX10\"")
        XCTAssertEqual(GameSettings.value(of: "r_Width", in: text), "1000")
        XCTAssertFalse(prefs.options.windowed)
    }

    func testResetGameSettingsOverwritesPlayerValues() throws {
        try prefs.setWindowed(false)
        try prefs.resetGameSettings(screen: (1512, 945))
        let text = try String(contentsOf: cfg)
        XCTAssertEqual(GameSettings.value(of: "r_driver", in: text), "\"DX9\"")
        XCTAssertEqual(GameSettings.value(of: "r_Fullscreen", in: text), "0")
        XCTAssertEqual(GameSettings.value(of: "r_Width", in: text), "1512")
        XCTAssertEqual(GameSettings.value(of: "locale", in: text), "en_us")
        XCTAssertTrue(prefs.options.windowed)
    }

    func testRepairRefusesWhileTheGameRuns() async throws {
        probe.running[LauncherSupervisor.gamePattern] = 1
        let recorder = StepRecorder()
        do {
            try await prefs.repair(engine: SetupEngine(stateURL: paths.stateFile, performer: recorder), resources: res)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? PreferencesError, .launcherRunning)
        }
        XCTAssertEqual(recorder.done, [])
        XCTAssertTrue(SetupState.load(from: paths.stateFile).isComplete)
    }

    func testRepairRedoesFilesButNeverTheGameOrItsSettings() async throws {
        try FileManager.default.removeItem(at: paths.installedDwmapi)
        let recorder = StepRecorder()
        try await prefs.repair(engine: SetupEngine(stateURL: paths.stateFile, performer: recorder), resources: res)
        XCTAssertEqual(recorder.done, [.runtime, .webView2, .directX, .mtld3d, .registry])
        XCTAssertEqual(try String(contentsOf: paths.installedDwmapi), "fix-v2")
        XCTAssertEqual(GameSettings.value(of: "r_driver", in: try String(contentsOf: cfg)), "\"DX10\"")
    }
}
