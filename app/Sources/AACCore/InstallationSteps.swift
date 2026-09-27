import Foundation

public enum Installation {
    static func replace(_ dest: URL, with src: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: dest)
        try fm.copyItem(at: src, to: dest)
    }

    // Wine only loads mtld3d.dll if a marker copy exists in the prefix
    public static func installMTLd3DFiles(paths: AppPaths) throws {
        let m = paths.runtime.appendingPathComponent("mtld3d")
        try replace(paths.syswow64.appendingPathComponent("d3d9.dll"), with: m.appendingPathComponent("native/i386-windows/d3d9.dll"))
        try replace(paths.syswow64.appendingPathComponent("mtld3d.dll"), with: m.appendingPathComponent("prefix-markers/syswow64/mtld3d.dll"))
        try replace(paths.system32.appendingPathComponent("mtld3d.dll"), with: m.appendingPathComponent("prefix-markers/system32/mtld3d.dll"))
    }

    // next to the launcher, so only the launcher picks up the native override
    public static func installDwmapi(paths: AppPaths, resources: BundleResources) throws {
        try replace(paths.installedDwmapi, with: resources.dwmapi)
    }
}

public struct InstallationSteps: SetupStepPerforming {
    let paths: AppPaths
    let resources: BundleResources
    let runner: CommandRunning
    let downloader: Downloader
    let screenSize: (Int, Int)

    public init(paths: AppPaths, resources: BundleResources, runner: CommandRunning = ProcessRunner(),
                downloader: Downloader = Downloader(), screenSize: (Int, Int)) {
        self.paths = paths; self.resources = resources; self.runner = runner
        self.downloader = downloader; self.screenSize = screenSize
    }

    var options: LaunchOptions { SetupState.load(from: paths.stateFile).options }
    var wine: Wine { Wine(paths: paths, options: options, runner: runner) }
    var sevenZip: SevenZip { SevenZip(binary: resources.sevenZip, runner: runner) }

    public func perform(_ step: SetupStep) async throws {
        let fm = FileManager.default
        switch step {
        case .runtime:
            let lock = try RuntimeLock.load(from: resources.runtimeLock)
            try await RuntimeInstaller(paths: paths, runner: runner).install(tarball: resources.runtimeTarball, lock: lock)

        case .prefix:
            try fm.createDirectory(at: paths.root, withIntermediateDirectories: true)
            try await wine.boot()

        case .webView2:
            let exe = try await downloader.fetch(Components.webView2, into: paths.cache)
            let tmp = paths.cache.appendingPathComponent("webview2-unpack")
            try? fm.removeItem(at: tmp)
            try await sevenZip.extract(exe, to: tmp.appendingPathComponent("outer"))
            let outer = try fm.contentsOfDirectory(atPath: tmp.appendingPathComponent("outer").path)
            guard let edge = outer.first(where: { $0.hasPrefix("MicrosoftEdge_X64_") }) else {
                throw InstallError.commandFailed("WebView2 package layout changed")
            }
            try await sevenZip.extract(tmp.appendingPathComponent("outer/\(edge)"), to: tmp.appendingPathComponent("edge"))
            try await sevenZip.extract(tmp.appendingPathComponent("edge/MSEDGE.7z"), to: tmp.appendingPathComponent("edge"))
            try? fm.removeItem(at: paths.webView2Dir)
            try fm.moveItem(at: tmp.appendingPathComponent("edge/Chrome-bin/\(Components.webView2Version)"), to: paths.webView2Dir)
            try? fm.removeItem(at: tmp)

        case .directX:
            let exe = try await downloader.fetch(Components.directX, into: paths.cache)
            let tmp = paths.cache.appendingPathComponent("directx-unpack")
            try? fm.removeItem(at: tmp)
            try await sevenZip.extract(exe, to: tmp, patterns: ["*d3dx9_42_x86.cab", "*d3dx9_43_x86.cab",
                                                                "*D3DCompiler_42_x86.cab", "*D3DCompiler_43_x86.cab"], flat: true)
            for cab in try fm.contentsOfDirectory(atPath: tmp.path) where cab.hasSuffix(".cab") {
                try await sevenZip.extract(tmp.appendingPathComponent(cab), to: tmp.appendingPathComponent("dll"), patterns: ["*.dll"], flat: true)
            }
            for dll in try fm.contentsOfDirectory(atPath: tmp.appendingPathComponent("dll").path) {
                try Installation.replace(paths.syswow64.appendingPathComponent(dll.lowercased()),
                                         with: tmp.appendingPathComponent("dll/\(dll)"))
            }
            for needed in ["d3dx9_42.dll", "d3dcompiler_42.dll"] where !fm.fileExists(atPath: paths.syswow64.appendingPathComponent(needed).path) {
                throw InstallError.commandFailed("DirectX: \(needed) missing after extraction")
            }
            try? fm.removeItem(at: tmp)

        case .mtld3d:
            try Installation.installMTLd3DFiles(paths: paths)

        case .registry:
            try await wine.importRegistry(RegistryFixes.reg(renderer: options.renderer))

        case .launcher:
            let installer = try await downloader.fetch(Components.installer, into: paths.cache)
            let dest = paths.driveC.appendingPathComponent("aac-installer.exe")
            try Installation.replace(dest, with: installer)
            defer { try? fm.removeItem(at: dest) }
            // exits non-zero because its DirectX web setup is disabled; the launcher check below is what counts
            _ = try? await wine.run(["C:\\aac-installer.exe", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART",
                                     "/DIR=C:\\Games\\AAClassic"])
            try await wine.waitForServer()
            guard fm.fileExists(atPath: paths.launcherExe.path) else {
                throw InstallError.commandFailed("the official installer did not create the launcher")
            }
            try Installation.installDwmapi(paths: paths, resources: resources)

        case .gameSettings:
            guard let docs = paths.documentsDir() else { throw InstallError.commandFailed("no Windows user in prefix") }
            try fm.createDirectory(at: docs, withIntermediateDirectories: true)
            let cfg = docs.appendingPathComponent("system.cfg")
            let existing = (try? String(contentsOf: cfg)) ?? ""
            let text = GameSettings.merge(existing, GameSettings.defaults(width: screenSize.0, height: screenSize.1), overwrite: false)
            try text.write(to: cfg, atomically: true, encoding: .utf8)
        }
    }
}
