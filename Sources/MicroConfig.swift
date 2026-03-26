import Foundation

struct MicroOption {
    let key: String
    let defaultValue: String
    var currentValue: String
}

struct MicroConfig {

    static let configDir: String = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MacMicro/micro").path
    }()

    static let settingsPath: String = {
        return (configDir as NSString).appendingPathComponent("settings.json")
    }()

    /// Create config directory and install the macmicro plugin if needed.
    static func ensureDefaults() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir) {
            try? fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        }
        installPlugin()
    }

    /// Install/update the macmicro plugin into the config dir.
    private static func installPlugin() {
        let fm = FileManager.default
        let pluginDir = (configDir as NSString).appendingPathComponent("plug/macmicro")
        if !fm.fileExists(atPath: pluginDir) {
            try? fm.createDirectory(atPath: pluginDir, withIntermediateDirectories: true)
        }

        // Copy plugin files from app bundle
        let bundle = Bundle.main
        for file in ["macmicro.lua", "repo.json"] {
            if let src = bundle.path(forResource: file, ofType: nil, inDirectory: "plugin/macmicro") {
                let dst = (pluginDir as NSString).appendingPathComponent(file)
                try? fm.removeItem(atPath: dst)
                try? fm.copyItem(atPath: src, toPath: dst)
            }
        }
    }

    /// Parse `micro -options` for all available options and their defaults,
    /// then overlay with user's settings.json for current values.
    static func loadAllOptions() -> [MicroOption] {
        let defaults = parseMicroOptions()
        let overrides = readSettingsJSON()

        return defaults.map { opt in
            var o = opt
            if let val = overrides[opt.key] {
                o.currentValue = val
            }
            return o
        }
    }

    /// Run `micro -options` and parse the output.
    private static func parseMicroOptions() -> [MicroOption] {
        let microPath = findMicroBinary()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: microPath)
        process.arguments = ["-config-dir", configDir, "-options"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var options: [MicroOption] = []
        let lines = output.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i]
            // Lines like: -autoindent value
            if line.hasPrefix("-"), line.hasSuffix(" value") {
                let key = String(line.dropFirst().dropLast(" value".count))
                // Next line: \tDefault value: 'xxx'
                if i + 1 < lines.count,
                   let range = lines[i + 1].range(of: "'"),
                   let endRange = lines[i + 1].range(of: "'", range: range.upperBound..<lines[i + 1].endIndex) {
                    let defaultVal = String(lines[i + 1][range.upperBound..<endRange.lowerBound])
                    options.append(MicroOption(key: key, defaultValue: defaultVal, currentValue: defaultVal))
                    i += 2
                    continue
                }
            }
            i += 1
        }
        return options
    }

    /// Read the user's settings.json, returning string values for all keys.
    private static func readSettingsJSON() -> [String: String] {
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }

        var result: [String: String] = [:]
        for (key, value) in json {
            switch value {
            case let b as Bool: result[key] = b ? "true" : "false"
            case let n as NSNumber: result[key] = "\(n)"
            case let s as String: result[key] = s
            default: result[key] = "\(value)"
            }
        }
        return result
    }

    private static func findMicroBinary() -> String {
        for path in ["/opt/homebrew/bin/micro", "/usr/local/bin/micro", "/usr/bin/micro"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return "/opt/homebrew/bin/micro"
    }
}
