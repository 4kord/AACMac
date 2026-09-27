import XCTest
@testable import AACCore

final class RosettaTests: XCTestCase {
    func testInstalledWhenAnIntelBinaryRuns() async {
        let r = StubRunner()
        let ok = await Rosetta.isInstalled(runner: r)
        XCTAssertTrue(ok)
        XCTAssertEqual(r.calls, [["arch", "-x86_64", "/usr/bin/true"]])
    }

    func testMissingWhenArchFails() async {
        let r = StubRunner(); r.status = 1
        let ok = await Rosetta.isInstalled(runner: r)
        XCTAssertFalse(ok)
    }

    func testMissingWhenArchCannotRun() async {
        let r = StubRunner(); r.error = CocoaError(.fileNoSuchFile)
        let ok = await Rosetta.isInstalled(runner: r)
        XCTAssertFalse(ok)
    }
}
