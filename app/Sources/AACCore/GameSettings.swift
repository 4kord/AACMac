import Foundation

// The game rewrites system.cfg in lowercase and carries unknown lines along at the end,
// so keys compare case-insensitively and a later copy of a key would override the game's.
public enum GameSettings {
    public static func defaults(width: Int, height: Int) -> [(key: String, value: String)] {
        [
            ("r_driver", "\"DX9\""),
            ("r_fullscreen", "0"),
            ("r_width", "\(width)"),
            ("r_height", "\(height)"),
            ("r_multithreaded", "1"),
            ("sys_spec_full", "2"),
            ("option_animation", "2"), ("option_character_lod", "2"), ("option_effect", "2"),
            ("option_shader_quality", "2"), ("option_shadow_dist", "2"), ("option_terrain_detail", "2"),
            ("option_terrain_lod", "2"), ("option_texture_bg", "2"), ("option_texture_character", "2"),
            ("option_view_dist_ratio", "2"), ("option_view_dist_ratio_vegetation", "2"),
            ("option_view_distance", "2"), ("option_volumetric_effect", "2"), ("option_water", "2"),
            // off until MTLd3D's shadow artifacts are fixed
            ("option_use_shadow", "0"), ("option_use_cloud", "1"), ("option_use_hdr", "0"),
            ("option_use_dof", "0"), ("option_use_water_reflection", "0"),
        ]
    }

    public static func value(of key: String, in text: String) -> String? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let (k, v) = parse(line), k.caseInsensitiveCompare(key) == .orderedSame { return v }
        }
        return nil
    }

    public static func merge(_ existing: String, _ settings: [(key: String, value: String)], overwrite: Bool) -> String {
        var lines = existing.isEmpty ? [] : existing.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        for (key, value) in settings {
            let matches = lines.indices.filter { parse(Substring(lines[$0]))?.0.caseInsensitiveCompare(key) == .orderedSame }
            if let first = matches.first {
                if overwrite {
                    lines[first] = "\(key) = \(value)"
                    for i in matches.dropFirst().reversed() { lines.remove(at: i) }
                }
            } else {
                lines.append("\(key) = \(value)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func removingDuplicates(_ text: String) -> String {
        var seen = Set<String>()
        return text.components(separatedBy: "\n").filter { line in
            guard let (key, _) = parse(Substring(line)) else { return true }
            return seen.insert(key.lowercased()).inserted
        }.joined(separator: "\n")
    }

    public static func removeDuplicates(inFileAt url: URL) throws {
        guard let text = try? String(contentsOf: url) else { return }
        let cleaned = removingDuplicates(text)
        if cleaned != text { try cleaned.write(to: url, atomically: true, encoding: .utf8) }
    }

    private static func parse(_ line: Substring) -> (String, String)? {
        guard !line.hasPrefix("--"), let eq = line.firstIndex(of: "=") else { return nil }
        let k = line[..<eq].trimmingCharacters(in: .whitespaces)
        let v = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        return k.isEmpty ? nil : (k, v)
    }
}
