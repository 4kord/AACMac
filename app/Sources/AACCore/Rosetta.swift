import Foundation

public enum Rosetta {
    public static let installCommand = "/usr/sbin/softwareupdate --install-rosetta --agree-to-license"

    // /usr/bin/true is universal, so this only fails without Rosetta
    public static func isInstalled(runner: CommandRunning) async -> Bool {
        guard let r = try? await runner.run(URL(fileURLWithPath: "/usr/bin/arch"), ["-x86_64", "/usr/bin/true"],
                                            env: [:], cwd: nil) else { return false }
        return r.status == 0
    }
}
