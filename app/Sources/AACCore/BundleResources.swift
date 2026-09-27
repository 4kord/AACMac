import Foundation

public struct BundleResources {
    public let runtimeTarball: URL
    public let runtimeLock: URL
    public let dwmapi: URL
    public let sevenZip: URL

    public init(runtimeTarball: URL, runtimeLock: URL, dwmapi: URL, sevenZip: URL) {
        self.runtimeTarball = runtimeTarball; self.runtimeLock = runtimeLock
        self.dwmapi = dwmapi; self.sevenZip = sevenZip
    }

    public static func from(directory r: URL) -> BundleResources? {
        let res = BundleResources(runtimeTarball: r.appendingPathComponent("runtime.tar.xz"),
                                  runtimeLock: r.appendingPathComponent("runtime-lock.json"),
                                  dwmapi: r.appendingPathComponent("dwmapi.dll"),
                                  sevenZip: r.appendingPathComponent("7zz"))
        let all = [res.runtimeTarball, res.runtimeLock, res.dwmapi, res.sevenZip]
        return all.allSatisfy { FileManager.default.fileExists(atPath: $0.path) } ? res : nil
    }

    public static func main(environment: [String: String] = ProcessInfo.processInfo.environment) -> BundleResources? {
        if let dir = environment["AAC_RESOURCES"] { return from(directory: URL(fileURLWithPath: dir)) }
        guard let r = Bundle.main.resourceURL else { return nil }
        return from(directory: r)
    }
}
