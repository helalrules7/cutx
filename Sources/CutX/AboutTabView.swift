import AppKit

final class AboutTabView: NSView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        L10n.applyDirection(to: self)

        let column = NSStackView()
        column.translatesAutoresizingMaskIntoConstraints = false
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 10
        addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
        ])

        if let icon = NSApp.applicationIconImage {
            let view = NSImageView()
            view.image = icon
            view.translatesAutoresizingMaskIntoConstraints = false
            column.addArrangedSubview(view)
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: 64),
                view.heightAnchor.constraint(equalToConstant: 64),
            ])
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1.0.0"
        addCentered(
            NSTextField(labelWithString: "CutX \(version)"),
            to: column,
            font: .systemFont(ofSize: 19, weight: .semibold)
        )

        addCentered(
            NSTextField(labelWithString: T("about.tagline")),
            to: column,
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )

        addCentered(
            NSTextField(labelWithString: T("about.madeBy")),
            to: column,
            font: .systemFont(ofSize: 13, weight: .medium)
        )

        let profile = linkButton("@helalrules7", action: #selector(openProfile))
        column.addArrangedSubview(profile)

        let body = NSTextField(wrappingLabelWithString: T("about.explanation"))
        body.font = .systemFont(ofSize: 11)
        body.textColor = .secondaryLabelColor
        body.alignment = .center
        body.translatesAutoresizingMaskIntoConstraints = false
        column.addArrangedSubview(body)
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -20),
        ])

        let coffee = NSButton(
            title: "\(T("about.coffee"))  ☕",
            target: self,
            action: #selector(openCoffee)
        )
        coffee.bezelStyle = .rounded
        coffee.controlSize = .large
        coffee.translatesAutoresizingMaskIntoConstraints = false
        column.addArrangedSubview(coffee)
        column.setCustomSpacing(18, after: body)

        let source = linkButton(T("about.source"), action: #selector(openSource))
        column.addArrangedSubview(source)

        addCentered(
            NSTextField(labelWithString: T("about.license")),
            to: column,
            font: .systemFont(ofSize: 10),
            color: .tertiaryLabelColor
        )
        column.setCustomSpacing(18, after: source)
    }

    private func addCentered(
        _ field: NSTextField,
        to column: NSStackView,
        font: NSFont,
        color: NSColor = .labelColor
    ) {
        field.font = font
        field.textColor = color
        field.alignment = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        column.addArrangedSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(greaterThanOrEqualTo: column.leadingAnchor),
            field.trailingAnchor.constraint(lessThanOrEqualTo: column.trailingAnchor),
        ])
    }

    /// A borderless button styled as a link, so it reads as tappable without
    /// pulling visual weight away from the coffee button.
    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .linkColor
        button.font = .systemFont(ofSize: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
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
