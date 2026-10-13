public enum RegistryFixes {
    // bump when the fixes change so existing installs re-apply them
    public static let version = 4

    // the only combination that draws WebView2 under Wine
    public static let webView2Arguments = [
        "--disable-gpu", "--disable-gpu-compositing", "--disable-d3d11", "--disable-direct-composition",
        "--disable-features=DirectCompositionVideoOverlays,CalculateNativeWinOcclusion",
        "--no-sandbox", "--in-process-gpu",
        "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
    ].joined(separator: " ")

    public static func reg(renderer: Renderer) -> String {
        let d3d9 = renderer == .metal ? "\"d3d9\"=\"native\"" : "\"d3d9\"=-"
        let webView2Dir = Components.webView2WindowsDir.replacingOccurrences(of: "\\", with: "\\\\")
        // the addon manager finds WebView2 only through EdgeUpdate and can't use the launcher's dwmapi hook
        // WebView2 on win7: Wine has no DirectComposition, https://bugs.winehq.org/show_bug.cgi?id=58921
        return """
        Windows Registry Editor Version 5.00

        [HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]
        "pv"="\(Components.webView2Version)"

        [HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Microsoft\\EdgeUpdate\\ClientState\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}]
        "EBWebView"="\(webView2Dir)"

        [HKEY_CURRENT_USER\\Software\\Wine\\WebView2]
        "AdditionalBrowserArguments"="\(webView2Arguments)"

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe]
        "Version"="win7"

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\msedgewebview2.exe\\DllOverrides]
        "vulkan-1"="native"

        [HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
        "directmanipulation"=""
        "dxwebsetup.exe"=""

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\ArcheAge Classic Launcher.exe\\DllOverrides]
        "dwmapi"="native,builtin"

        [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\addon_manager.exe\\DllOverrides]
        "dwmapi"="builtin"

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
