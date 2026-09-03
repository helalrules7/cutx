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
    private let volumeLabel = NSTextField(labelWithString: "")

    init(preferences: Preferences, player: SoundPlayer) {
        self.preferences = preferences
        self.player = player
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        L10n.applyDirection(to: self)

        let master = NSButton(
            checkboxWithTitle: T("sounds.play"),
            target: self,
            action: #selector(togglePlaySound(_:))
        )
        master.state = preferences.playSound ? .on : .off
        master.translatesAutoresizingMaskIntoConstraints = false

        volumeLabel.stringValue = T("sounds.volume")
        volumeLabel.font = .systemFont(ofSize: 12)
        volumeLabel.textColor = .secondaryLabelColor
        volumeLabel.alignment = .natural
        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        volumeLabel.setContentHuggingPriority(.required, for: .horizontal)

        volumeSlider.minValue = 0
        volumeSlider.maxValue = 1
        volumeSlider.doubleValue = preferences.volume
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged(_:))
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false

        let volumeRow = NSStackView(views: [volumeLabel, volumeSlider])
        volumeRow.translatesAutoresizingMaskIntoConstraints = false
        volumeRow.orientation = .horizontal
        volumeRow.alignment = .centerY
        volumeRow.spacing = 10

        let heading = NSTextField(labelWithString: T("sounds.cutSound"))
        heading.font = .systemFont(ofSize: 10, weight: .semibold)
        heading.textColor = .tertiaryLabelColor
        heading.alignment = .natural
        heading.translatesAutoresizingMaskIntoConstraints = false

        let soundList = NSStackView()
        soundList.translatesAutoresizingMaskIntoConstraints = false
        soundList.orientation = .vertical
        soundList.alignment = .leading
        soundList.spacing = 8

        for (index, sound) in CutSound.all.enumerated() {
            let radio = NSButton(
                radioButtonWithTitle: T("sound.\(sound.id)"),
                target: self,
                action: #selector(selectSound(_:))
            )
            radio.tag = index
            radio.state = sound.id == preferences.cutSound ? .on : .off
            radio.translatesAutoresizingMaskIntoConstraints = false
            radios.append(radio)

            let preview = NSButton(title: "▶", target: self, action: #selector(previewSound(_:)))
            preview.bezelStyle = .rounded
            preview.controlSize = .small
            preview.tag = index
            preview.translatesAutoresizingMaskIntoConstraints = false
            preview.setContentHuggingPriority(.required, for: .horizontal)
            previewButtons.append(preview)

            let row = NSStackView(views: [radio, preview])
            row.translatesAutoresizingMaskIntoConstraints = false
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            soundList.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: soundList.leadingAnchor),
                row.trailingAnchor.constraint(lessThanOrEqualTo: soundList.trailingAnchor),
            ])
        }

        let column = NSStackView(views: [master, volumeRow, heading, soundList])
        column.translatesAutoresizingMaskIntoConstraints = false
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 16
        column.setCustomSpacing(24, after: volumeRow)
        addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: 26),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            master.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            volumeRow.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 20),
            volumeRow.trailingAnchor.constraint(lessThanOrEqualTo: column.trailingAnchor),
            volumeSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            heading.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            soundList.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 20),
            soundList.trailingAnchor.constraint(lessThanOrEqualTo: column.trailingAnchor),
        ])

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
