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
    // last Windows 7 build; newer ones draw nothing under Wine
    public static let webView2 = Component(
        id: "webview2",
        url: URL(string: "https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/updt/2023/09/microsoftedgestandaloneinstallerx64_1c890b4b8dd6b7c93da98ebdc08ecdc5e30e50cb.exe")!,
        sha256: "eac95c8095ec5f9971eade9827d8fb67fd251f5c16e702b5312d31067e39119b",
        fileName: "webview2-109.0.1518.140-x64.exe")
    public static let webView2Version = "109.0.1518.140"

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
