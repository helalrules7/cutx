import Foundation
import Testing
@testable import CutXCore

@Test func automaticIsTheDefault() {
    #expect(Preferences(defaults: freshDefaults()).language == .automatic)
}

@Test func languageSelectionPersists() {
    let defaults = freshDefaults()
    let prefs = Preferences(defaults: defaults)
    prefs.language = .arabic
    #expect(Preferences(defaults: defaults).language == .arabic)
}

@Test func unknownStoredLanguageFallsBackToAutomatic() {
    let defaults = freshDefaults()
    defaults.set("klingon", forKey: "language")
    #expect(Preferences(defaults: defaults).language == .automatic)
}

@Test func everyLanguageHasACodeAndANativeName() {
    for language in Language.allCases {
        #expect(!language.nativeName.isEmpty)
        if language != .automatic { #expect(!language.code.isEmpty) }
    }
}

// Arabic is the only right-to-left language shipped; the flag drives the whole
// mirrored layout, so it is worth asserting rather than assuming.
@Test func onlyArabicIsRightToLeft() {
    #expect(Language.arabic.isRightToLeft == true)
    for language in Language.allCases where language != .arabic {
        #expect(language.isRightToLeft == false)
    }
}
