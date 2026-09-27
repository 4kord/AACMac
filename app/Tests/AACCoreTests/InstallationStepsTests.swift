import XCTest
@testable import AACCore

final class InstallationStepsTests: XCTestCase {
    var root: URL!
    var paths: AppPaths!
    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        paths = AppPaths(root: root, logs: root.appendingPathComponent("logs"))
    }

    func testInstallsMTLd3DPrefixFiles() throws {
        let fm = FileManager.default
        let m = paths.runtime.appendingPathComponent("mtld3d")
        for (dir, name) in [("native/i386-windows", "d3d9.dll"), ("prefix-markers/syswow64", "mtld3d.dll"), ("prefix-markers/system32", "mtld3d.dll")] {
            try fm.createDirectory(at: m.appendingPathComponent(dir), withIntermediateDirectories: true)
            try Data(dir.utf8).write(to: m.appendingPathComponent(dir).appendingPathComponent(name))
        }
        try fm.createDirectory(at: paths.syswow64, withIntermediateDirectories: true)
        try fm.createDirectory(at: paths.system32, withIntermediateDirectories: true)
        try Data("wine placeholder".utf8).write(to: paths.syswow64.appendingPathComponent("d3d9.dll"))

        try Installation.installMTLd3DFiles(paths: paths)

        XCTAssertEqual(try String(contentsOf: paths.syswow64.appendingPathComponent("d3d9.dll")), "native/i386-windows")
        XCTAssertEqual(try String(contentsOf: paths.syswow64.appendingPathComponent("mtld3d.dll")), "prefix-markers/syswow64")
        XCTAssertEqual(try String(contentsOf: paths.system32.appendingPathComponent("mtld3d.dll")), "prefix-markers/system32")
    }

    func testInstallsDwmapiNextToLauncher() throws {
        let src = root.appendingPathComponent("res/dwmapi.dll")
        try FileManager.default.createDirectory(at: src.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fix".utf8).write(to: src)
        let res = BundleResources(runtimeTarball: src, runtimeLock: src, dwmapi: src, sevenZip: src)
        try Installation.installDwmapi(paths: paths, resources: res)
        XCTAssertEqual(try String(contentsOf: paths.installedDwmapi), "fix")
        try Installation.installDwmapi(paths: paths, resources: res)
    }
}
