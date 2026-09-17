import Foundation

/// The single place the app asks whether the user has Pro.
///
/// Every Pro feature routes through `hasPro` and nothing else, so when the
/// In-App Purchase is added there is exactly one function to change, and no
/// feature can accidentally forget the check.
///
/// It returns `true` today: the purchase does not exist yet, and shipping the
/// feature open lets it be tested and used before any paywall is built.
public enum Entitlements {
    /// Set by tests to exercise both sides of the gate. Never set in the app.
    public static var proOverrideForTesting: Bool?

    public static var hasPro: Bool {
        if let override = proOverrideForTesting { return override }
        return true
    }

    /// True in App Store builds, where a purchase is possible at all.
    public static var isProBuild: Bool {
        #if APPSTORE
        return true
        #else
        return false
        #endif
    }
}
