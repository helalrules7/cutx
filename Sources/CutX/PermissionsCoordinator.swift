import AppKit
import ApplicationServices

/// The permissions CutX cannot work without, each able to report its own real
/// state rather than having the app infer it from behavior.
enum Permission: CaseIterable {
    case accessibility

    var title: String {
        switch self {
        case .accessibility: return T("permission.accessibility")
        }
    }

    var detail: String {
        switch self {
        case .accessibility:
            return T("permission.accessibility.detail")
        }
    }

    var isGranted: Bool {
        switch self {
        case .accessibility: return AXIsProcessTrusted()
        }
    }

    func openSettings() {
        let pane: String
        switch self {
        case .accessibility: pane = "Privacy_Accessibility"
        }
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        )
    }
}

enum PermissionsCoordinator {
    static var allGranted: Bool {
        Permission.allCases.allSatisfy(\.isGranted)
    }

    /// Shows the system's own Accessibility prompt. macOS only honors this once
    /// per app, which is exactly why the checklist exists.
    static func requestAccessibilityPrompt() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

}
