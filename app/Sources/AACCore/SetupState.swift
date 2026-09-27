import Foundation

public enum SetupStep: String, Codable, CaseIterable {
    case runtime, prefix, webView2, directX, mtld3d, registry, launcher, gameSettings
}

public struct SetupState: Codable, Equatable {
    public var completed: [SetupStep] = []
    public var options = LaunchOptions()
    public init() {}

    public var isComplete: Bool { Set(completed) == Set(SetupStep.allCases) }

    public static func load(from url: URL) -> SetupState {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(SetupState.self, from: data) else { return SetupState() }
        return s
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url, options: .atomic)
    }
}
