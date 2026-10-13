import Foundation

public enum Issue: Equatable {
    case runtimeOutdated, dwmapiMissingOrChanged, registryMissing, webView2Missing
}

public struct QuickCheck {
    let paths: AppPaths
    let resources: BundleResources

    public init(paths: AppPaths, resources: BundleResources) {
        self.paths = paths
        self.resources = resources
    }

    public func issues() throws -> [Issue] {
        var out: [Issue] = []
        let lock = try RuntimeLock.load(from: resources.runtimeLock)
        if RuntimeInstaller(paths: paths, runner: ProcessRunner()).installedRevision() != lock.revision { out.append(.runtimeOutdated) }
        if (try? FileHash.sha256(of: paths.installedDwmapi)) != (try? FileHash.sha256(of: resources.dwmapi)) {
            out.append(.dwmapiMissingOrChanged)
        }
        if !FileManager.default.fileExists(atPath: paths.webView2Dir.appendingPathComponent("msedgewebview2.exe").path) {
            out.append(.webView2Missing)
        }
        let userReg = (try? String(contentsOf: paths.prefix.appendingPathComponent("user.reg"))) ?? ""
        if !RegistryFixes.isApplied(userReg: userReg) { out.append(.registryMissing) }
        return out
    }

    public static func stepsToRedo(for issues: [Issue]) -> [SetupStep] {
        var steps = Set<SetupStep>()
        for i in issues {
            switch i {
            case .runtimeOutdated: steps.formUnion([.runtime, .mtld3d])
            case .registryMissing: steps.insert(.registry)
            case .webView2Missing: steps.insert(.webView2)
            case .dwmapiMissingOrChanged: break  // the caller copies it directly
            }
        }
        return SetupStep.allCases.filter(steps.contains)
    }
}
