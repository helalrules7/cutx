import Testing
@testable import CutXCore

// Until the In-App Purchase exists, Pro is on for everyone. This test is the
// reminder to change it deliberately rather than by accident.
@Test func proIsOpenUntilThePurchaseExists() {
    Entitlements.proOverrideForTesting = nil
    #expect(Entitlements.hasPro == true)
}

@Test func theOverrideWins() {
    Entitlements.proOverrideForTesting = false
    #expect(Entitlements.hasPro == false)
    Entitlements.proOverrideForTesting = true
    #expect(Entitlements.hasPro == true)
    Entitlements.proOverrideForTesting = nil
}
