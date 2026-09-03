import AppKit

/// Template images for the status item. `isTemplate = true` is what lets macOS
/// invert them for a dark menu bar; a colored image there is an immediate
/// giveaway that an app was built without reading the guidelines.
enum MenuBarIcon {
    private static var cache: [Bool: NSImage] = [:]

    static func image(open: Bool) -> NSImage {
        if let cached = cache[open] { return cached }

        let size = NSSize(width: 16, height: 17)
        let image = NSImage(size: size, flipped: false) { rect in
            let glyph = rect.insetBy(dx: 0.5, dy: 0.5)
            NSColor.black.setFill()
            let parts = ScissorsShape.parts(open: open, in: glyph)
            parts.solid.fill()
            parts.rings.fill()
            return true
        }
        image.isTemplate = true
        cache[open] = image
        return image
    }
}
