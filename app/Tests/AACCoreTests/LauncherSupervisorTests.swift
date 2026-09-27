import XCTest
@testable import AACCore

private final class FakeProbe: ProcessProbe {
    var launcher = 0
    var game = 0
    var webviewAfterStart: [Int] = [5]   // WebView2 count seen after the 1st, 2nd, … start
    var starts = 0
    func count(_ pattern: String) -> Int {
        switch pattern {
        case LauncherSupervisor.webViewPattern:
            return starts == 0 ? 0 : webviewAfterStart[min(starts - 1, webviewAfterStart.count - 1)]
        case LauncherSupervisor.launcherPattern: return launcher
        case LauncherSupervisor.gamePattern: return game
        default: return 0
        }
    }
}

final class LauncherSupervisorTests: XCTestCase {
    var stops = 0
    var sleeps: [Double] = []

    override func setUp() { stops = 0; sleeps = [] }

    fileprivate func make(_ probe: FakeProbe, start: (() throws -> Void)? = nil) -> LauncherSupervisor {
        LauncherSupervisor(probe: probe,
                           start: { try start?(); probe.starts += 1 },
                           stop: { self.stops += 1 },
                           sleep: { self.sleeps.append($0) })
    }

    func testStartsOnceWhenTheUIComesUp() async throws {
        let p = FakeProbe()
        let outcome = try await make(p).launch()
        XCTAssertEqual(outcome, .started)
        XCTAssertEqual(p.starts, 1)
        XCTAssertEqual(stops, 0)
        XCTAssertEqual(sleeps, [25])
    }

    func testRestartsWhenWebView2DiesAtStartup() async throws {
        let p = FakeProbe(); p.webviewAfterStart = [0, 6]
        let outcome = try await make(p).launch()
        XCTAssertEqual(outcome, .started)
        XCTAssertEqual(p.starts, 2)
        XCTAssertEqual(stops, 1)
    }

    func testGivesUpAfterTwoRestarts() async throws {
        let p = FakeProbe(); p.webviewAfterStart = [0]
        let outcome = try await make(p).launch()
        XCTAssertEqual(outcome, .failed(attempts: 3))
        XCTAssertEqual(p.starts, 3)
        XCTAssertEqual(stops, 3)
    }

    func testSecondCopyDoesNotStartAnotherLauncher() async throws {
        let p = FakeProbe(); p.launcher = 1
        let outcome = try await make(p).launch()
        XCTAssertEqual(outcome, .alreadyRunning)
        XCTAssertEqual(p.starts, 0)
        XCTAssertEqual(stops, 0)
    }

    func testRunningGameIsNeverStopped() async throws {
        let p = FakeProbe(); p.game = 1
        let outcome = try await make(p).launch()
        XCTAssertEqual(outcome, .alreadyRunning)
        XCTAssertEqual(stops, 0)
    }

    func testStartErrorPropagates() async {
        let p = FakeProbe()
        do {
            _ = try await make(p, start: { throw InstallError.commandFailed("no wine") }).launch()
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? InstallError, .commandFailed("no wine"))
        }
    }
}
