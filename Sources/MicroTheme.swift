import AppKit

struct MicroTheme {
    let defaultBg: NSColor
    let isDark: Bool

    var appearance: NSAppearance? {
        NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    static func load() -> MicroTheme {
        let colorscheme = readColorscheme()
        let lines = loadColorschemeLines(name: colorscheme)
        let bg = parseDefaultBg(lines: lines)
        let brightness = bg.brightnessComponent
        return MicroTheme(defaultBg: bg, isDark: brightness < 0.5)
    }

    /// Load theme for a specific colorscheme name.
    static func load(colorscheme: String) -> MicroTheme {
        let lines = loadColorschemeLines(name: colorscheme)
        let bg = parseDefaultBg(lines: lines)
        let brightness = bg.brightnessComponent
        return MicroTheme(defaultBg: bg, isDark: brightness < 0.5)
    }

    private static func readColorscheme() -> String {
        let options = MicroConfig.loadAllOptions()
        return options.first(where: { $0.key == "colorscheme" })?.currentValue ?? "default"
    }

    private static func loadColorschemeLines(name: String) -> [String] {
        let userPath = (MicroConfig.configDir as NSString).appendingPathComponent("colorschemes/\(name).micro")
        if let contents = try? String(contentsOfFile: userPath, encoding: .utf8) {
            return resolveIncludes(lines: contents.components(separatedBy: .newlines))
        }
        let builtinURL = "https://raw.githubusercontent.com/zyedidia/micro/master/runtime/colorschemes/\(name).micro"
        if let url = URL(string: builtinURL),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            return resolveIncludes(lines: contents.components(separatedBy: .newlines))
        }
        return []
    }

    private static func resolveIncludes(lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("include ") {
                let name = trimmed.dropFirst("include ".count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                result.append(contentsOf: loadColorschemeLines(name: name))
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func parseDefaultBg(lines: [String]) -> NSColor {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("color-link default ") else { continue }
            let value = trimmed.dropFirst("color-link default ".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let parts = value.split(separator: ",", maxSplits: 1)
            if parts.count > 1, let bg = colorFromHex(String(parts[1]).trimmingCharacters(in: .whitespaces)) {
                return bg
            }
        }
        return NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1) // monokai default
    }

    private static func colorFromHex(_ hex: String) -> NSColor? {
        var h = hex
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return NSColor(
            red: CGFloat((val >> 16) & 0xFF) / 255.0,
            green: CGFloat((val >> 8) & 0xFF) / 255.0,
            blue: CGFloat(val & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
