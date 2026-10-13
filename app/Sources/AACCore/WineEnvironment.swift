public enum WineEnvironment {
    public static func make(paths: AppPaths, options: LaunchOptions) -> [String: String] {
        var env = [
            "WINEPREFIX": paths.prefix.path,
            "DYLD_LIBRARY_PATH": paths.runtime.appendingPathComponent("lib/external").path,
            "WINEMSYNC": "1",
            "WINE_LARGE_ADDRESS_AWARE": "1",
            "WINEDEBUG": "-all",
            "WEBVIEW2_BROWSER_EXECUTABLE_FOLDER": Components.webView2WindowsDir,
            // steady 60 on a 120 Hz panel; MTLd3D's simulated HDR posterizes this game's colors
            "MTLD3D_CONFIG": "present.maxFps=60;color.hdr.enable=false;color.space=accurate",
        ]
        if options.x87 { env["ROSETTA_X87_PATH"] = paths.rosettax87.path }
        if options.metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        return env
    }
}
