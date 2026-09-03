import AppKit
import CutXCore

/// A small translucent panel that appears near the pointer at cut time and fades.
///
/// macOS exposes no way to dim icons inside a Finder window the way Windows does,
/// so this plus the menu-bar badge is the feedback CutX can actually guarantee.
final class CutHUD {
    private let preferences: Preferences
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func show(count: Int) {
        guard preferences.showIndicator, count > 0 else { return }

        dismissWorkItem?.cancel()
        panel?.orderOut(nil)

        let key = count == 1 ? "hud.itemCut" : "hud.itemsCut"
        let label = NSTextField(labelWithString: "✂︎  " + String(format: T(key), count))
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.sizeToFit()

        let padding = NSSize(width: 22, height: 14)
        let size = NSSize(
            width: label.frame.width + padding.width * 2,
            height: label.frame.height + padding.height * 2
        )

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        label.frame.origin = NSPoint(x: padding.width, y: padding.height)
        background.addSubview(label)

        let panel = NSPanel(
            contentRect: NSRect(origin: origin(for: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.orderFrontRegardless()
        self.panel = panel

        let dismiss = DispatchWorkItem { [weak self] in self?.fadeOut() }
        dismissWorkItem = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: dismiss)
    }

    /// Just above and right of the pointer, nudged back on screen if it would clip.
    private func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        var point = NSPoint(x: mouse.x + 16, y: mouse.y + 16)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            let frame = screen.visibleFrame
            point.x = min(point.x, frame.maxX - size.width - 8)
            point.y = min(point.y, frame.maxY - size.height - 8)
            point.x = max(point.x, frame.minX + 8)
            point.y = max(point.y, frame.minY + 8)
        }
        return point
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1
            if self?.panel === panel { self?.panel = nil }
        }
    }
}
