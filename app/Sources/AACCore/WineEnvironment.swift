public enum WineEnvironment {
    // the only combination that paints into the launcher window under Wine
    public static let webView2Arguments = [
        "--disable-gpu", "--disable-gpu-compositing", "--disable-d3d11", "--disable-direct-composition",
        "--disable-features=DirectCompositionVideoOverlays,CalculateNativeWinOcclusion",
        "--no-sandbox", "--in-process-gpu", "--use-gl=swiftshader",
    ].joined(separator: " ")

    public static func make(paths: AppPaths, options: LaunchOptions) -> [String: String] {
        var env = [
            "WINEPREFIX": paths.prefix.path,
            "DYLD_LIBRARY_PATH": paths.runtime.appendingPathComponent("lib/external").path,
            "WINEMSYNC": "1",
            "WINE_LARGE_ADDRESS_AWARE": "1",
            "WINEDEBUG": "-all",
            "WEBVIEW2_BROWSER_EXECUTABLE_FOLDER": "C:\\WebView2",
            "WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS": webView2Arguments,
        ]
        if options.x87 { env["ROSETTA_X87_PATH"] = paths.rosettax87.path }
        if options.metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        return env
    }
}
