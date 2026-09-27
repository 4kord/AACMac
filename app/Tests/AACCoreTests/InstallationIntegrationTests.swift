import XCTest
@testable import AACCore

final class InstallationIntegrationTests: XCTestCase {
    func testFullSetupWithoutLauncher() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["AAC_INTEGRATION"] == "1")
        let env = ProcessInfo.processInfo.environment
        let res = BundleResources(runtimeTarball: URL(fileURLWithPath: env["AAC_RUNTIME"]!),
                                  runtimeLock: URL(fileURLWithPath: env["AAC_RUNTIME_LOCK"]!),
                                  dwmapi: URL(fileURLWithPath: env["AAC_DWMAPI"]!),
                                  sevenZip: URL(fileURLWithPath: env["AAC_7ZZ"]!))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aac-it-\(UUID().uuidString)")
        let paths = AppPaths(root: root, logs: root.appendingPathComponent("logs"))
        let steps = InstallationSteps(paths: paths, resources: res, screenSize: (1512, 945))
        for s in [SetupStep.runtime, .prefix, .webView2, .directX, .mtld3d, .registry] { try await steps.perform(s) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.webView2Dir.appendingPathComponent("msedgewebview2.exe").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.syswow64.appendingPathComponent("d3dx9_42.dll").path))
        let userReg = try String(contentsOf: paths.prefix.appendingPathComponent("user.reg"))
        XCTAssertTrue(RegistryFixes.isApplied(userReg: userReg))
        await Wine(paths: paths, options: LaunchOptions(), runner: ProcessRunner()).killServer()
        try? FileManager.default.removeItem(at: root)
    }
}
