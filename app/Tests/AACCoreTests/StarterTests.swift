import XCTest
@testable import AACCore

final class StarterTests: XCTestCase {
    var paths: AppPaths!, res: BundleResources!, probe: StubProbe!

    override func setUpWithError() throws {
        (paths, res) = try Fixture.healthyInstallation()
        probe = StubProbe()
    }

    var starter: Starter { Starter(paths: paths, resources: res, probe: probe) }

    func testHealthyInstallationLaunches() throws {
        XCTAssertEqual(try starter.plan(), .launch)
    }

    func testFirstRunSetsUp() throws {
        try FileManager.default.removeItem(at: paths.stateFile)
        XCTAssertEqual(try starter.plan(), .setup)
    }

    func testInterruptedSetupIsNotMistakenForAnInstallation() throws {
        var s = SetupState(); s.completed = [.runtime, .prefix]
        try s.save(to: paths.stateFile)
        XCTAssertEqual(try starter.plan(), .setup)
    }

    func testSecondCopyAttachesToTheRunningLauncher() throws {
        probe.running[LauncherSupervisor.launcherPattern] = 1
        XCTAssertEqual(try starter.plan(), .alreadyRunning)
    }

    func testLauncherSelfUpdateOnlyRestoresDwmapi() throws {
        try FileManager.default.removeItem(at: paths.installedDwmapi)
        XCTAssertEqual(try starter.plan(), .repair(steps: [], restoreDwmapi: true))
    }

    func testRepairRunsOnlyTheNeededStepsAndRestoresDwmapi() async throws {
        try "r0\n".write(to: paths.runtimeRevisionFile, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: paths.installedDwmapi)
        let plan = try starter.plan()
        XCTAssertEqual(plan, .repair(steps: [.runtime, .mtld3d], restoreDwmapi: true))

        let recorder = StepRecorder()
        try await starter.prepare(plan, engine: SetupEngine(stateURL: paths.stateFile, performer: recorder))
        XCTAssertEqual(recorder.done, [.runtime, .mtld3d])
        XCTAssertEqual(try String(contentsOf: paths.installedDwmapi), "fix-v2")
        XCTAssertTrue(SetupState.load(from: paths.stateFile).isComplete)
    }

    func testEveryStepHasATitle() {
        for step in SetupStep.allCases { XCTAssertFalse(step.title.isEmpty, step.rawValue) }
    }
}
