import XCTest
@testable import AACCore

final class DevOverridesTests: XCTestCase {
    func testRootOverride() {
        let p = AppPaths.standard(environment: ["AAC_ROOT": "/tmp/aac"])
        XCTAssertEqual(p.root.path, "/tmp/aac")
        XCTAssertEqual(p.logs.path, "/tmp/aac/logs")
        XCTAssertTrue(AppPaths.standard(environment: [:]).root.path.hasSuffix("Application Support/ArcheAge Classic"))
    }

    func testResourcesNeedEveryFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in ["runtime.tar.xz", "runtime-lock.json", "dwmapi.dll"] { try Data().write(to: dir.appendingPathComponent(f)) }
        XCTAssertNil(BundleResources.from(directory: dir))
        try Data().write(to: dir.appendingPathComponent("7zz"))
        XCTAssertEqual(BundleResources.main(environment: ["AAC_RESOURCES": dir.path])?.sevenZip.lastPathComponent, "7zz")
    }
}
