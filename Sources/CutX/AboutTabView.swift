import AppKit

final class AboutTabView: NSView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        if let icon = NSApp.applicationIconImage {
            let view = NSImageView(frame: NSRect(x: 198, y: 306, width: 64, height: 64))
            view.image = icon
            addSubview(view)
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.0.0"
        addCentered(
            NSTextField(labelWithString: "CutX \(version)"),
            font: .systemFont(ofSize: 19, weight: .semibold),
            y: 276,
            height: 26
        )

        addCentered(
            NSTextField(labelWithString: "Cut and paste files in Finder, the way you expect."),
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            y: 254,
            height: 18
        )

        let credit = NSTextField(labelWithString: "Made by Ahmed Helal")
        credit.font = .systemFont(ofSize: 13, weight: .medium)
        credit.alignment = .center
        credit.frame = NSRect(x: 30, y: 212, width: 400, height: 20)
        addSubview(credit)

        let profile = linkButton("@helalrules7", action: #selector(openProfile))
        profile.frame = NSRect(x: 155, y: 190, width: 150, height: 20)
        addSubview(profile)

        let body = NSTextField(wrappingLabelWithString: """
            CutX never touches your files — it asks Finder to do the move. That is \
            why undo, the progress window, and the Replace / Keep Both dialog all \
            work exactly as they normally do.
            """)
        body.font = .systemFont(ofSize: 11)
        body.textColor = .secondaryLabelColor
        body.alignment = .center
        body.frame = NSRect(x: 50, y: 132, width: 360, height: 48)
        addSubview(body)

        let coffee = NSButton(
            title: "Buy me a coffee  ☕",
            target: self,
            action: #selector(openCoffee)
        )
        coffee.bezelStyle = .rounded
        coffee.controlSize = .large
        coffee.frame = NSRect(x: 148, y: 84, width: 164, height: 34)
        addSubview(coffee)

        let source = linkButton("View source on GitHub", action: #selector(openSource))
        source.frame = NSRect(x: 148, y: 56, width: 164, height: 22)
        addSubview(source)

        addCentered(
            NSTextField(labelWithString: "Free and open source · MIT licensed · Sound credits in ATTRIBUTIONS.md"),
            font: .systemFont(ofSize: 10),
            color: .tertiaryLabelColor,
            y: 24,
            height: 16
        )
    }

    private func addCentered(
        _ field: NSTextField,
        font: NSFont,
        color: NSColor = .labelColor,
        y: CGFloat,
        height: CGFloat
    ) {
        field.font = font
        field.textColor = color
        field.alignment = .center
        field.frame = NSRect(x: 20, y: y, width: 420, height: height)
        addSubview(field)
    }

    /// A borderless button styled as a link, so it reads as tappable without
    /// pulling visual weight away from the coffee button.
    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .linkColor
        button.font = .systemFont(ofSize: 12)
        return button
    }

    @objc private func openCoffee() {
        open("https://buymeacoffee.com/ahmedhelal")
    }

    @objc private func openSource() {
        open("https://github.com/helalrules7/cutx")
    }

    @objc private func openProfile() {
        open("https://github.com/helalrules7")
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
