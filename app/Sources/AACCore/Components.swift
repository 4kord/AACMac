import Foundation

public struct Component: Equatable {
    public let id: String
    public let url: URL
    public let sha256: String?
    public let fileName: String

    public init(id: String, url: URL, sha256: String?, fileName: String) {
        self.id = id; self.url = url; self.sha256 = sha256; self.fileName = fileName
    }
}

public enum Components {
    public static let webView2 = Component(
        id: "webview2",
        url: URL(string: "https://github.com/4kord/AACMac/releases/download/webview2-155.0.4283.45/Microsoft.WebView2.FixedVersionRuntime.155.0.4283.45.x64.cab")!,
        sha256: "ec533bf1b7354d288703cf821a2d640d0130108224f93e330bb9c09faf3f8010",
        fileName: "webview2-155.0.4283.45-x64.cab")
    public static let webView2Version = "155.0.4283.45"
    public static let webView2WindowsDir = "C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application\\\(webView2Version)"

    public static let directX = Component(
        id: "directx",
        url: URL(string: "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe")!,
        sha256: "053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b",
        fileName: "directx_Jun2010_redist.exe")

    // not pinned: the publisher replaces it on every update
    public static let installer = Component(
        id: "installer",
        url: URL(string: "https://patch.aa-classic.com/ArcheAge%20Classic%20-%20Installer.exe")!,
        sha256: nil,
        fileName: "ArcheAge Classic - Installer.exe")
}
