public enum RegistryFixes {
    // bump when the fixes change so existing installs re-apply them
    public static let version = 1

    public static func reg(renderer: Renderer) -> String {
        let d3d9 = renderer == .metal ? "\"d3d9\"=\"native\"" : "\"d3d9\"=-"
        return """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe]
        "Version"="win7"

        [HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
        "directmanipulation"=""
        "dxwebsetup.exe"=""

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\ArcheAge Classic Launcher.exe\\DllOverrides]
        "dwmapi"="native,builtin"

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\archeage.exe\\DllOverrides]
        \(d3d9)
        "d3dx9_42"="native,builtin"
        "d3dx9_43"="native,builtin"
        "d3dcompiler_42"="native,builtin"
        "d3dcompiler_43"="native,builtin"

        [HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Client]
        "Enabled"=dword:00000000
        "DisabledByDefault"=dword:00000001

        [HKEY_CURRENT_USER\\Software\\ArcheAgeClassicMac]
        "FixesVersion"=dword:\(String(format: "%08x", version))

        """
    }

    public static func isApplied(userReg: String) -> Bool {
        guard let range = userReg.range(of: "[Software\\\\ArcheAgeClassicMac]") else { return false }
        let section = userReg[range.upperBound...].prefix(200)
        return section.contains("\"FixesVersion\"=dword:\(String(format: "%08x", version))")
    }
}
