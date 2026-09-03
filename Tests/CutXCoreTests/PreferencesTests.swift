import Foundation
import Testing
@testable import CutXCore

private func freshDefaults() -> UserDefaults {
    let name = "CutXTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func defaultsMatchSpec() {
    let prefs = Preferences(defaults: freshDefaults())
    #expect(prefs.playSound == true)
    #expect(prefs.showIndicator == true)
    #expect(prefs.controlHotkeys == false)
    #expect(prefs.launchAtLogin == false)
    #expect(prefs.cutSound == "snip")
}

@Test func cutSoundPersists() {
    let defaults = freshDefaults()
    let prefs = Preferences(defaults: defaults)
    prefs.cutSound = "scissors"
    #expect(Preferences(defaults: defaults).cutSound == "scissors")
}

// A value written by an older or newer build must never leave the app mute.
@Test func unknownCutSoundFallsBackToDefault() {
    let defaults = freshDefaults()
    let prefs = Preferences(defaults: defaults)
    prefs.cutSound = "does-not-exist"
    #expect(prefs.cutSound == CutSound.fallback)
}

@Test func everyListedSoundHasALabel() {
    #expect(CutSound.all.count == 6)
    #expect(CutSound.all.allSatisfy { !$0.label.isEmpty })
    #expect(CutSound.all.contains { $0.id == CutSound.fallback })
}

@Test func valuesPersist() {
    let defaults = freshDefaults()
    let prefs = Preferences(defaults: defaults)
    prefs.playSound = false
    prefs.controlHotkeys = true

    let reloaded = Preferences(defaults: defaults)
    #expect(reloaded.playSound == false)
    #expect(reloaded.controlHotkeys == true)
    #expect(reloaded.showIndicator == true)
}
