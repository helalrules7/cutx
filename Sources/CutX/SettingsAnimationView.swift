import AppKit
import QuartzCore

/// A looping mock of the System Settings pane, with a cursor that moves to the
/// CutX row and flips its toggle on. Watching it once beats reading a sentence
/// about where to click.
final class SettingsAnimationView: NSView {
    private let windowLayer = CALayer()
    private let toggleTrack = CALayer()
    private let toggleKnob = CALayer()
    private let cursor = CAShapeLayer()
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func buildLayers() {
        guard let root = layer else { return }

        windowLayer.frame = bounds
        windowLayer.cornerRadius = 10
        windowLayer.borderWidth = 1
        root.addSublayer(windowLayer)

        let rowHeight: CGFloat = 26
        for index in 0..<3 {
            let row = CALayer()
            row.frame = CGRect(
                x: 12,
                y: bounds.height - 40 - CGFloat(index) * (rowHeight + 6),
                width: bounds.width - 24,
                height: rowHeight
            )
            row.cornerRadius = 5
            row.name = index == 1 ? "cutx" : "other"
            windowLayer.addSublayer(row)

            let label = CATextLayer()
            label.string = ["Terminal", "CutX", "Shortcuts"][index]
            label.fontSize = 11
            label.contentsScale = 2
            label.frame = CGRect(x: 10, y: 6, width: 140, height: 14)
            row.addSublayer(label)

            if index == 1 {
                toggleTrack.frame = CGRect(x: row.bounds.width - 48, y: 4, width: 34, height: 18)
                toggleTrack.cornerRadius = 9
                row.addSublayer(toggleTrack)

                toggleKnob.frame = CGRect(x: 2, y: 2, width: 14, height: 14)
                toggleKnob.cornerRadius = 7
                toggleTrack.addSublayer(toggleKnob)
            }
        }

        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: -14))
        path.addLine(to: CGPoint(x: 4, y: -10.5))
        path.addLine(to: CGPoint(x: 6.5, y: -15))
        path.addLine(to: CGPoint(x: 9, y: -14))
        path.addLine(to: CGPoint(x: 6.5, y: -9.5))
        path.addLine(to: CGPoint(x: 11, y: -9))
        path.closeSubpath()
        cursor.path = path
        cursor.lineWidth = 1
        cursor.frame = bounds
        root.addSublayer(cursor)

        applyColors()
    }

    private func applyColors() {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        windowLayer.backgroundColor = (dark ? NSColor(white: 0.16, alpha: 1)
                                            : NSColor(white: 0.98, alpha: 1)).cgColor
        windowLayer.borderColor = NSColor.separatorColor.cgColor
        toggleKnob.backgroundColor = NSColor.white.cgColor
        cursor.fillColor = (dark ? NSColor.white : NSColor.black).cgColor
        cursor.strokeColor = (dark ? NSColor.black : NSColor.white).cgColor

        for row in windowLayer.sublayers ?? [] {
            row.backgroundColor = (row.name == "cutx"
                ? NSColor.controlAccentColor.withAlphaComponent(dark ? 0.22 : 0.14)
                : NSColor(white: dark ? 0.22 : 0.93, alpha: 1)).cgColor
            for sublayer in row.sublayers ?? [] {
                (sublayer as? CATextLayer)?.foregroundColor = NSColor.labelColor.cgColor
            }
        }
        setToggle(on: false, animated: false)
    }

    func start() {
        stop()
        runLoopOnce()
        timer = Timer.scheduledTimer(withTimeInterval: 4.2, repeats: true) { [weak self] _ in
            self?.runLoopOnce()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func runLoopOnce() {
        setToggle(on: false, animated: false)

        let start = CGPoint(x: bounds.width * 0.18, y: bounds.height * 0.20)
        let target = CGPoint(x: bounds.width - 43, y: bounds.height - 40 - 32 + 13)

        cursor.position = start
        let move = CABasicAnimation(keyPath: "position")
        move.fromValue = NSValue(point: start)
        move.toValue = NSValue(point: target)
        move.duration = 1.4
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        move.fillMode = .forwards
        move.isRemovedOnCompletion = false
        cursor.add(move, forKey: "move")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { [weak self] in
            guard let self else { return }
            // A quick dip in scale reads as a click.
            let press = CABasicAnimation(keyPath: "transform.scale")
            press.fromValue = 1.0
            press.toValue = 0.82
            press.duration = 0.09
            press.autoreverses = true
            self.cursor.add(press, forKey: "press")
            self.setToggle(on: true, animated: true)
        }
    }

    private func setToggle(on: Bool, animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.22)
        toggleTrack.backgroundColor = (on ? NSColor.systemGreen
                                          : NSColor(white: 0.6, alpha: 1)).cgColor
        toggleKnob.frame.origin.x = on ? toggleTrack.bounds.width - 16 : 2
        CATransaction.commit()
    }
}
