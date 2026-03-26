import AppKit

struct FontSettings {

    private static let nameKey = "MacMicro.fontName"
    private static let sizeKey = "MacMicro.fontSize"

    static func loadFont() -> NSFont {
        let defaults = UserDefaults.standard
        let size = defaults.double(forKey: sizeKey)
        let fontSize = size > 0 ? CGFloat(size) : 14

        if let name = defaults.string(forKey: nameKey),
           let font = NSFont(name: name, size: fontSize) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    static func save(name: String, size: CGFloat) {
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: nameKey)
        defaults.set(Double(size), forKey: sizeKey)
    }
}
