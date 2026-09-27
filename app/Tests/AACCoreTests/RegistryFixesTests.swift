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
        XCTAssertTrue(r.contains("SCHANNEL\\Protocols\\TLS 1.3\\Client]\n\"Enabled\"=dword:00000000\n\"DisabledByDefault\"=dword:00000001"))
        for dll in ["d3dx9_42", "d3dx9_43", "d3dcompiler_42", "d3dcompiler_43"] {
            XCTAssertTrue(r.contains("\"\(dll)\"=\"native,builtin\""), dll)
        }
        XCTAssertTrue(r.contains("\"FixesVersion\"=dword:0000000\(RegistryFixes.version)"))
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
