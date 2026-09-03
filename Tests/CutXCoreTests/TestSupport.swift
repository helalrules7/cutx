import Foundation

func freshDefaults() -> UserDefaults {
    let name = "CutXTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
