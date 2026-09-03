import AppKit
import ApplicationServices

/// The permissions CutX cannot work without, each able to report its own real
/// state rather than having the app infer it from behavior.
enum Permission: CaseIterable {
    case accessibility
    case automation

    var title: String {
        switch self {
        case .accessibility: return T("permission.accessibility")
        case .automation: return T("permission.automation")
        }
    }

    var detail: String {
        switch self {
        case .accessibility:
            return T("permission.accessibility.detail")
        case .automation:
            return T("permission.automation.detail")
        }
    }

    var isGranted: Bool {
        switch self {
        case .accessibility: return AXIsProcessTrusted()
        case .automation: return PermissionsCoordinator.canAutomateFinder()
        }
    }

    func openSettings() {
        let pane: String
        switch self {
        case .accessibility: pane = "Privacy_Accessibility"
        case .automation: pane = "Privacy_Automation"
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

    /// Asks macOS whether CutX may send Apple Events to Finder, without prompting.
    static func canAutomateFinder() -> Bool {
        var target = AEAddressDesc()
        let bundleID = FinderBridge.bundleIdentifier
        let created = bundleID.withCString { pointer -> OSErr in
            AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target)
        }
        guard created == noErr else { return false }
        defer { AEDisposeDesc(&target) }

        return AEDeterminePermissionToAutomateTarget(
            &target, typeWildCard, typeWildCard, false
        ) == noErr
    }
}
