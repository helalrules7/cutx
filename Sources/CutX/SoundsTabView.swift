import AppKit
import CutXCore

/// A list of sounds with a ▶ on every row. Something chosen by ear needs to be
/// audible from the list — a column of names tells the user nothing.
final class SoundsTabView: NSView {
    private let preferences: Preferences
    private let player: SoundPlayer
    private var radios: [NSButton] = []
    private var previewButtons: [NSButton] = []
    private let volumeSlider = NSSlider()
    private let volumeLabel = NSTextField(labelWithString: "Volume")

    init(preferences: Preferences, player: SoundPlayer) {
        self.preferences = preferences
        self.player = player
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        let master = NSButton(
            checkboxWithTitle: "Play sound",
            target: self,
            action: #selector(togglePlaySound(_:))
        )
        master.state = preferences.playSound ? .on : .off
        master.frame = NSRect(x: 30, y: 352, width: 300, height: 22)
        addSubview(master)

        volumeLabel.font = .systemFont(ofSize: 12)
        volumeLabel.textColor = .secondaryLabelColor
        volumeLabel.frame = NSRect(x: 50, y: 320, width: 60, height: 18)
        addSubview(volumeLabel)

        volumeSlider.minValue = 0
        volumeSlider.maxValue = 1
        volumeSlider.doubleValue = preferences.volume
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged(_:))
        volumeSlider.frame = NSRect(x: 112, y: 318, width: 220, height: 22)
        addSubview(volumeSlider)

        let heading = NSTextField(labelWithString: "CUT SOUND")
        heading.font = .systemFont(ofSize: 10, weight: .semibold)
        heading.textColor = .tertiaryLabelColor
        heading.frame = NSRect(x: 30, y: 286, width: 200, height: 14)
        addSubview(heading)

        var y: CGFloat = 254
        for (index, sound) in CutSound.all.enumerated() {
            let radio = NSButton(
                radioButtonWithTitle: sound.label,
                target: self,
                action: #selector(selectSound(_:))
            )
            radio.tag = index
            radio.state = sound.id == preferences.cutSound ? .on : .off
            radio.frame = NSRect(x: 50, y: y, width: 240, height: 22)
            addSubview(radio)
            radios.append(radio)

            let preview = NSButton(title: "▶", target: self, action: #selector(previewSound(_:)))
            preview.bezelStyle = .rounded
            preview.controlSize = .small
            preview.tag = index
            preview.frame = NSRect(x: 300, y: y - 1, width: 40, height: 24)
            addSubview(preview)
            previewButtons.append(preview)

            y -= 30
        }

        updateEnabledState()
    }

    private func updateEnabledState() {
        let on = preferences.playSound
        volumeSlider.isEnabled = on
        volumeLabel.textColor = on ? .secondaryLabelColor : .tertiaryLabelColor
        for control in radios { control.isEnabled = on }
        // Preview stays live even when sounds are off: asking to hear an option is
        // itself the request to hear it.
    }

    @objc private func togglePlaySound(_ sender: NSButton) {
        preferences.playSound = sender.state == .on
        updateEnabledState()
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        preferences.volume = sender.doubleValue
    }

    @objc private func selectSound(_ sender: NSButton) {
        guard sender.tag < CutSound.all.count else { return }
        preferences.cutSound = CutSound.all[sender.tag].id
        player.preview(CutSound.all[sender.tag].id)
        for (index, radio) in radios.enumerated() {
            radio.state = index == sender.tag ? .on : .off
        }
    }

    @objc private func previewSound(_ sender: NSButton) {
        guard sender.tag < CutSound.all.count else { return }
        player.preview(CutSound.all[sender.tag].id)
    }
}
