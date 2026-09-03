import AppKit
import CutXCore

/// Loads every shipped sound once at startup — each is a few kilobytes, and
/// decoding on the first ⌘X would put audible latency exactly where it is most
/// noticeable.
final class SoundPlayer {
    private let preferences: Preferences
    private var cutSounds: [String: NSSound] = [:]
    private let pasteSound: NSSound?

    init(preferences: Preferences) {
        self.preferences = preferences
        for sound in CutSound.all {
            cutSounds[sound.id] = SoundPlayer.load(sound.id)
        }
        pasteSound = SoundPlayer.load("paste")
    }

    private static func load(_ name: String) -> NSSound? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "wav",
            subdirectory: "sounds"
        ) else {
            NSLog("CutX: missing sound resource sounds/\(name).wav")
            return nil
        }
        return NSSound(contentsOf: url, byReference: true)
    }

    func playCut() {
        guard preferences.playSound else { return }
        play(cutSounds[preferences.cutSound] ?? cutSounds[CutSound.fallback])
    }

    func playPaste() {
        guard preferences.playSound else { return }
        play(pasteSound)
    }

    /// Plays a sound the user just picked from the menu, ignoring `playSound` —
    /// asking to hear an option is itself the request to hear it.
    func preview(_ id: String) {
        play(cutSounds[id])
    }

    private func play(_ sound: NSSound?) {
        guard let sound else { return }
        sound.volume = Float(preferences.volume)
        // Cutting twice in quick succession should retrigger, not overlap.
        if sound.isPlaying { sound.stop() }
        sound.play()
    }
}
