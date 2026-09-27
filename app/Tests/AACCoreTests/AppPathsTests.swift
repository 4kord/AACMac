import XCTest
@testable import AACCore

final class AppPathsTests: XCTestCase {
    func testLayout() {
        let p = AppPaths(root: URL(fileURLWithPath: "/r"), logs: URL(fileURLWithPath: "/l"))
        XCTAssertEqual(p.runtime.path, "/r/runtime")
        XCTAssertEqual(p.prefix.path, "/r/prefix")
        XCTAssertEqual(p.wine.path, "/r/runtime/bin/wine")
        XCTAssertEqual(p.gameDir.path, "/r/prefix/drive_c/Games/AAClassic")
        XCTAssertEqual(p.launcherExe.lastPathComponent, "ArcheAge Classic Launcher.exe")
        XCTAssertEqual(p.installedDwmapi.path, "/r/prefix/drive_c/Games/AAClassic/dwmapi.dll")
        XCTAssertEqual(p.syswow64.path, "/r/prefix/drive_c/windows/syswow64")
        XCTAssertEqual(p.rosettax87.path, "/r/runtime/x87/rosettax87")
    }

    func testStandardLocations() {
        let p = AppPaths.standard()
        XCTAssertTrue(p.root.path.hasSuffix("Library/Application Support/ArcheAge Classic"))
        XCTAssertTrue(p.logs.path.hasSuffix("Library/Logs/ArcheAge Classic"))
    }

    func testDocumentsDirFindsPrefixUser() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let p = AppPaths(root: root, logs: root)
        let users = p.driveC.appendingPathComponent("users")
        try FileManager.default.createDirectory(at: users.appendingPathComponent("Public"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: users.appendingPathComponent("player/Documents"), withIntermediateDirectories: true)
        XCTAssertEqual(p.documentsDir()?.path, users.appendingPathComponent("player/Documents/AAClassic").path)
    }
}
