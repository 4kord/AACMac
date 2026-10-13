import XCTest
@testable import AACCore

final class WineEnvironmentTests: XCTestCase {
    let paths = AppPaths(root: URL(fileURLWithPath: "/r"), logs: URL(fileURLWithPath: "/l"))

    func testBaseEnvironment() {
        let env = WineEnvironment.make(paths: paths, options: LaunchOptions())
        XCTAssertEqual(env["WINEPREFIX"], "/r/prefix")
        XCTAssertEqual(env["DYLD_LIBRARY_PATH"], "/r/runtime/lib/external")
        XCTAssertEqual(env["WINEMSYNC"], "1")
        XCTAssertEqual(env["WINE_LARGE_ADDRESS_AWARE"], "1")
        XCTAssertEqual(env["WINEDEBUG"], "-all")
        XCTAssertEqual(env["WEBVIEW2_BROWSER_EXECUTABLE_FOLDER"], "C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application\\155.0.4283.45")
        XCTAssertNil(env["WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS"])
        XCTAssertEqual(env["ROSETTA_X87_PATH"], "/r/runtime/x87/rosettax87")
        XCTAssertNil(env["MTL_HUD_ENABLED"])
    }

    func testOptionalKeys() {
        var o = LaunchOptions(); o.x87 = false; o.metalHUD = true
        let env = WineEnvironment.make(paths: paths, options: o)
        XCTAssertNil(env["ROSETTA_X87_PATH"])
        XCTAssertEqual(env["MTL_HUD_ENABLED"], "1")
    }

    func testDefaults() {
        let o = LaunchOptions()
        XCTAssertEqual(o.renderer, .metal)
        XCTAssertTrue(o.x87)
        XCTAssertFalse(o.metalHUD)
        XCTAssertTrue(o.windowed)
    }

    func testMTLd3DSettings() {
        XCTAssertEqual(WineEnvironment.make(paths: paths, options: LaunchOptions())["MTLD3D_CONFIG"],
                       "color.hdr.enable=false;color.space=accurate")
    }
}
