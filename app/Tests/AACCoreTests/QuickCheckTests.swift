import XCTest
@testable import AACCore

final class QuickCheckTests: XCTestCase {
    var root: URL!, paths: AppPaths!, res: BundleResources!

    override func setUpWithError() throws {
        let fm = FileManager.default
        root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        paths = AppPaths(root: root, logs: root)
        let resDir = root.appendingPathComponent("res")
        try fm.createDirectory(at: resDir, withIntermediateDirectories: true)
        try Data("fix-v2".utf8).write(to: resDir.appendingPathComponent("dwmapi.dll"))
        try #"{"revision":"r1","releaseTag":"t","asset":"a","sha256":"s","sizeBytes":0}"#.write(to: resDir.appendingPathComponent("lock.json"), atomically: true, encoding: .utf8)
        res = BundleResources(runtimeTarball: resDir, runtimeLock: resDir.appendingPathComponent("lock.json"),
                              dwmapi: resDir.appendingPathComponent("dwmapi.dll"), sevenZip: resDir)
        try fm.createDirectory(at: paths.runtime, withIntermediateDirectories: true)
        try "r1\n".write(to: paths.runtimeRevisionFile, atomically: true, encoding: .utf8)
        try fm.createDirectory(at: paths.gameDir, withIntermediateDirectories: true)
        try Data("exe".utf8).write(to: paths.launcherExe)
        try Data("fix-v2".utf8).write(to: paths.installedDwmapi)
        try fm.createDirectory(at: paths.webView2Dir, withIntermediateDirectories: true)
        try Data().write(to: paths.webView2Dir.appendingPathComponent("msedgewebview2.exe"))
        try fm.createDirectory(at: paths.syswow64, withIntermediateDirectories: true)
        try Data().write(to: paths.syswow64.appendingPathComponent("mtld3d.dll"))
        try "[Software\\\\ArcheAgeClassicMac] 1\n\"FixesVersion\"=dword:0000000\(RegistryFixes.version)\n"
            .write(to: paths.prefix.appendingPathComponent("user.reg"), atomically: true, encoding: .utf8)
    }

    func testHealthy() throws {
        XCTAssertEqual(try QuickCheck(paths: paths, resources: res).issues(), [])
    }

    func testLauncherUpdateRemovedDwmapi() throws {
        try FileManager.default.removeItem(at: paths.installedDwmapi)
        XCTAssertEqual(try QuickCheck(paths: paths, resources: res).issues(), [.dwmapiMissingOrChanged])
    }

    func testOldDwmapiIsReplaced() throws {
        try Data("fix-v1".utf8).write(to: paths.installedDwmapi)
        XCTAssertEqual(try QuickCheck(paths: paths, resources: res).issues(), [.dwmapiMissingOrChanged])
    }

    func testNewRuntimeInApp() throws {
        try "r0\n".write(to: paths.runtimeRevisionFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(try QuickCheck(paths: paths, resources: res).issues(), [.runtimeOutdated])
    }

    func testOutdatedRegistryFixes() throws {
        try "".write(to: paths.prefix.appendingPathComponent("user.reg"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try QuickCheck(paths: paths, resources: res).issues(), [.registryMissing])
    }

    func testStepsToRedo() {
        XCTAssertEqual(QuickCheck.stepsToRedo(for: [.runtimeOutdated]), [.runtime, .mtld3d])
        XCTAssertEqual(QuickCheck.stepsToRedo(for: [.registryMissing, .runtimeOutdated]), [.runtime, .mtld3d, .registry])
        XCTAssertEqual(QuickCheck.stepsToRedo(for: [.dwmapiMissingOrChanged]), [])
    }
}
