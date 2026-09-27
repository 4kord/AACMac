import XCTest
@testable import AACCore

private final class Recorder: SetupStepPerforming {
    var done: [SetupStep] = []
    var failOn: SetupStep?
    func perform(_ step: SetupStep) async throws {
        if step == failOn { throw URLError(.notConnectedToInternet) }
        done.append(step)
    }
}

final class SetupEngineTests: XCTestCase {
    var stateURL: URL!
    override func setUp() {
        stateURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    func testRunsAllStepsInOrder() async throws {
        let r = Recorder()
        try await SetupEngine(stateURL: stateURL, performer: r).runPending()
        XCTAssertEqual(r.done, SetupStep.allCases)
        XCTAssertTrue(SetupState.load(from: stateURL).isComplete)
    }

    func testResumesAtFailedStep() async throws {
        let r = Recorder(); r.failOn = .directX
        do { try await SetupEngine(stateURL: stateURL, performer: r).runPending(); XCTFail() }
        catch let f as SetupFailure { XCTAssertEqual(f.step, .directX) }
        XCTAssertEqual(SetupState.load(from: stateURL).completed, [.runtime, .prefix, .webView2])

        let r2 = Recorder()
        try await SetupEngine(stateURL: stateURL, performer: r2).runPending()
        XCTAssertEqual(r2.done, [.directX, .mtld3d, .registry, .launcher, .gameSettings])
    }

    func testResetRerunsOnlyThoseSteps() async throws {
        try await SetupEngine(stateURL: stateURL, performer: Recorder()).runPending()
        let e = SetupEngine(stateURL: stateURL, performer: Recorder())
        try e.reset([.registry])
        let r = Recorder()
        try await SetupEngine(stateURL: stateURL, performer: r).runPending()
        XCTAssertEqual(r.done, [.registry])
    }

    func testStateKeepsOptions() throws {
        var s = SetupState(); s.options.renderer = .wined3d
        try s.save(to: stateURL)
        XCTAssertEqual(SetupState.load(from: stateURL).options.renderer, .wined3d)
    }

    func testMissingOrCorruptStateStartsFresh() throws {
        try Data("{".utf8).write(to: stateURL)
        XCTAssertEqual(SetupState.load(from: stateURL), SetupState())
    }
}
