import Foundation

public struct AppPaths {
    public let root: URL
    public let logs: URL

    public init(root: URL, logs: URL) {
        self.root = root
        self.logs = logs
    }

    public static func standard(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppPaths {
        if let dir = environment["AAC_ROOT"] {
            let root = URL(fileURLWithPath: dir)
            return AppPaths(root: root, logs: root.appendingPathComponent("logs"))
        }
        let lib = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        return AppPaths(root: lib.appendingPathComponent("Application Support/ArcheAge Classic"),
                        logs: lib.appendingPathComponent("Logs/ArcheAge Classic"))
    }

    public var runtime: URL { root.appendingPathComponent("runtime") }
    public var prefix: URL { root.appendingPathComponent("prefix") }
    public var cache: URL { root.appendingPathComponent("cache") }
    public var stateFile: URL { root.appendingPathComponent("state.json") }
    public var driveC: URL { prefix.appendingPathComponent("drive_c") }
    public var gameDir: URL { driveC.appendingPathComponent("Games/AAClassic") }
    public var launcherExe: URL { gameDir.appendingPathComponent("ArcheAge Classic Launcher.exe") }
    public var installedDwmapi: URL { gameDir.appendingPathComponent("dwmapi.dll") }
    public var webView2Dir: URL { driveC.appendingPathComponent("WebView2") }
    public var syswow64: URL { driveC.appendingPathComponent("windows/syswow64") }
    public var system32: URL { driveC.appendingPathComponent("windows/system32") }
    public var wine: URL { runtime.appendingPathComponent("bin/wine") }
    public var wineserver: URL { runtime.appendingPathComponent("bin/wineserver") }
    public var rosettax87: URL { runtime.appendingPathComponent("x87/rosettax87") }
    public var runtimeRevisionFile: URL { runtime.appendingPathComponent("REVISION") }

    public func documentsDir() -> URL? {
        let users = driveC.appendingPathComponent("users")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: users.path)) ?? []
        guard let user = names.sorted().first(where: { $0 != "Public" && !$0.hasPrefix(".") }) else { return nil }
        return users.appendingPathComponent(user).appendingPathComponent("Documents/AAClassic")
    }
}
