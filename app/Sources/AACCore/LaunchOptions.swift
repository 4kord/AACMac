public enum Renderer: String, Codable, CaseIterable {
    case metal      // MTLd3D
    case wined3d
}

public struct LaunchOptions: Codable, Equatable {
    public var renderer: Renderer = .metal
    public var x87: Bool = true
    public var metalHUD: Bool = false
    public var windowed: Bool = true
    public init() {}
}
