import AppKit

/// One row per permission showing its real state. `refresh()` runs on a timer while
/// the window is open, so a row flips to ✓ the moment the user grants it — without
/// relaunching, and without having to guess whether it worked.
final class PermissionChecklistView: NSView {
    private struct Row {
        let permission: Permission
        let mark: NSTextField
        let button: NSButton
    }

    private var rows: [Row] = []
    private let onOpenSettings: (Permission) -> Void

    init(onOpenSettings: @escaping (Permission) -> Void) {
        self.onOpenSettings = onOpenSettings
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 118))
        buildRows()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildRows() {
        var y = frame.height - 46
        for (index, permission) in Permission.allCases.enumerated() {
            let mark = NSTextField(labelWithString: "○")
            mark.font = .systemFont(ofSize: 15, weight: .bold)
            mark.frame = NSRect(x: 0, y: y + 14, width: 22, height: 20)
            addSubview(mark)

            let title = NSTextField(labelWithString: permission.title)
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            title.frame = NSRect(x: 22, y: y + 14, width: 240, height: 20)
            addSubview(title)

            let detail = NSTextField(wrappingLabelWithString: permission.detail)
            detail.font = .systemFont(ofSize: 11)
            detail.textColor = .secondaryLabelColor
            detail.frame = NSRect(x: 22, y: y - 4, width: 310, height: 16)
            addSubview(detail)

            let button = NSButton(title: "Open", target: self, action: #selector(openTapped(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.tag = index
            button.frame = NSRect(x: 344, y: y + 12, width: 74, height: 24)
            addSubview(button)

            rows.append(Row(permission: permission, mark: mark, button: button))
            y -= 56
        }
    }

    func refresh() {
        for row in rows {
            let granted = row.permission.isGranted
            row.mark.stringValue = granted ? "✓" : "✗"
            row.mark.textColor = granted ? .systemGreen : .systemRed
            row.button.isHidden = granted
        }
    }

    @objc private func openTapped(_ sender: NSButton) {
        guard sender.tag < Permission.allCases.count else { return }
        onOpenSettings(Permission.allCases[sender.tag])
    }
}
