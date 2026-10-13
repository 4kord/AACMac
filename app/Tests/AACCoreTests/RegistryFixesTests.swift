import XCTest
@testable import AACCore

final class RegistryFixesTests: XCTestCase {
    func testContainsEveryFix() {
        let r = RegistryFixes.reg(renderer: .metal)
        XCTAssertTrue(r.hasPrefix("Windows Registry Editor Version 5.00"))
        XCTAssertTrue(r.contains("[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe]\n\"Version\"=\"win7\""))
        XCTAssertTrue(r.contains("\"directmanipulation\"=\"\""))
        XCTAssertTrue(r.contains("\"dxwebsetup.exe\"=\"\""))
        XCTAssertTrue(r.contains("[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\ArcheAge Classic Launcher.exe\\DllOverrides]\n\"dwmapi\"=\"native,builtin\""))
        XCTAssertTrue(r.contains("[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\addon_manager.exe\\DllOverrides]\n\"dwmapi\"=\"builtin\""))
        XCTAssertTrue(r.contains("SCHANNEL\\Protocols\\TLS 1.3\\Client]\n\"Enabled\"=dword:00000000\n\"DisabledByDefault\"=dword:00000001"))
        for dll in ["d3dx9_42", "d3dx9_43", "d3dcompiler_42", "d3dcompiler_43"] {
            XCTAssertTrue(r.contains("\"\(dll)\"=\"native,builtin\""), dll)
        }
        XCTAssertTrue(r.contains("\"FixesVersion\"=dword:0000000\(RegistryFixes.version)"))
    }

    func testWebView2BrowserArgumentsForTheRuntime() {
        let r = RegistryFixes.reg(renderer: .metal)
        XCTAssertTrue(r.contains("[HKEY_CURRENT_USER\\Software\\Wine\\WebView2]\n\"AdditionalBrowserArguments\"=\"--disable-gpu "))
        XCTAssertTrue(RegistryFixes.webView2Arguments.contains("--in-process-gpu --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader"))
        XCTAssertTrue(r.contains("[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe\\DllOverrides]\n\"vulkan-1\"=\"native\""))
        XCTAssertFalse(RegistryFixes.webView2Arguments.contains("\""))
        XCTAssertFalse(RegistryFixes.webView2Arguments.contains("\\"))
    }

    func testRegistersWebView2LikeEvergreenInstall() {
        let r = RegistryFixes.reg(renderer: .metal)
        XCTAssertTrue(r.contains("[HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]\n\"pv\"=\"155.0.4283.45\""))
        XCTAssertTrue(r.contains("[HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Microsoft\\EdgeUpdate\\ClientState\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]\n\"EBWebView\"=\"C:\\\\Program Files (x86)\\\\Microsoft\\\\EdgeWebView\\\\Application\\\\155.0.4283.45\""))
    }

    func testRendererSwitch() {
        XCTAssertTrue(RegistryFixes.reg(renderer: .metal).contains("\"d3d9\"=\"native\""))
        XCTAssertTrue(RegistryFixes.reg(renderer: .wined3d).contains("\"d3d9\"=-"))
    }

    func testDetectsAppliedFixesInUserReg() {
        let applied = "[Software\\\\ArcheAgeClassicMac] 1790000000\n\"FixesVersion\"=dword:0000000\(RegistryFixes.version)\n"
        XCTAssertTrue(RegistryFixes.isApplied(userReg: applied))
        XCTAssertFalse(RegistryFixes.isApplied(userReg: "[Software\\\\Wine]\n"))
        XCTAssertFalse(RegistryFixes.isApplied(userReg: "[Software\\\\ArcheAgeClassicMac] 1\n\"FixesVersion\"=dword:00000000\n"))
    }
}
