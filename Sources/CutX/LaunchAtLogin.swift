import Foundation
import ServiceManagement

/// Wraps SMAppService, the modern replacement for login-item helper apps.
/// Registration only works from a real .app bundle, never from `swift run`.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("CutX: launch-at-login change failed: \(error)")
            return false
        }
    }
}
