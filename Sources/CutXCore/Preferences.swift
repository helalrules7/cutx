import Foundation

public final class Preferences {
    private enum Key {
        static let playSound = "playSound"
        static let showIndicator = "showIndicator"
        static let controlHotkeys = "controlHotkeys"
        static let launchAtLogin = "launchAtLogin"
        static let cutSound = "cutSound"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.playSound: true,
            Key.showIndicator: true,
            Key.controlHotkeys: false,
            Key.launchAtLogin: false,
            Key.cutSound: CutSound.fallback,
        ])
    }

    public var playSound: Bool {
        get { defaults.bool(forKey: Key.playSound) }
        set { defaults.set(newValue, forKey: Key.playSound) }
    }

    public var showIndicator: Bool {
        get { defaults.bool(forKey: Key.showIndicator) }
        set { defaults.set(newValue, forKey: Key.showIndicator) }
    }

    public var controlHotkeys: Bool {
        get { defaults.bool(forKey: Key.controlHotkeys) }
        set { defaults.set(newValue, forKey: Key.controlHotkeys) }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    /// Reads back the default rather than a stored id we no longer ship, so a
    /// value left by another build can never leave the app silent.
    public var cutSound: String {
        get {
            let stored = defaults.string(forKey: Key.cutSound) ?? CutSound.fallback
            return CutSound.all.contains { $0.id == stored } ? stored : CutSound.fallback
        }
        set { defaults.set(newValue, forKey: Key.cutSound) }
    }
}

/// The cut sounds shipped in `Resources/sounds/`, in menu order.
public enum CutSound {
    public static let fallback = "snip"

    public static let all: [(id: String, label: String)] = [
        ("snip", "Snip"),
        ("tick", "Tick"),
        ("scissors", "Scissors"),
        ("paper", "Paper"),
        ("knife", "Knife"),
        ("bush", "Bush"),
    ]
}
