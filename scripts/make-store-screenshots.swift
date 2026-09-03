// Composes App Store screenshots at 2560×1600.
//
// The Mac App Store's smallest accepted size is 1280×800, and CutX's own window is
// a fraction of that. A raw screenshot would be a postage stamp in a sea of grey,
// so each shot places a real screenshot on a branded background with one line of
// copy — which is what every Mac listing does, including the competition.
//
// Usage: swiftc -O scripts/make-store-screenshots.swift -o /tmp/shots \
//          && /tmp/shots screenshots dist/store-screenshots
import AppKit

let inputDirectory = CommandLine.arguments[1]
let outputDirectory = CommandLine.arguments[2]

let size = NSSize(width: 2560, height: 1600)

struct Shot {
    let file: String
    let headline: String
    let sub: String
}

let shots = [
    Shot(file: "cut-indicator.png",
         headline: "Press ⌘X. Then ⌘V.",
         sub: "Your files move — just like on Windows."),
    Shot(file: "general.png",
         headline: "Finder does the moving",
         sub: "So undo, progress and conflict dialogs all still work."),
    Shot(file: "languages.png",
         headline: "Eleven languages",
         sub: "Including a properly mirrored Arabic interface."),
    Shot(file: "sounds.png",
         headline: "Six sounds, or none",
         sub: "Preview each one and pick what you can live with."),
    Shot(file: "about.png",
         headline: "Free. Open source.",
         sub: "No ads, no tracking, no account, no network."),
]

func draw(_ text: String, font: NSFont, color: NSColor, centeredIn rect: NSRect, y: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: style,
    ]
    let bounds = (text as NSString).boundingRect(
        with: NSSize(width: rect.width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin],
        attributes: attributes
    )
    (text as NSString).draw(
        with: NSRect(x: rect.minX, y: y, width: rect.width, height: bounds.height + 20),
        options: [.usesLineFragmentOrigin],
        attributes: attributes
    )
}

try? FileManager.default.createDirectory(
    atPath: outputDirectory, withIntermediateDirectories: true
)

for (index, shot) in shots.enumerated() {
    let sourcePath = "\(inputDirectory)/\(shot.file)"
    guard let screenshot = NSImage(contentsOfFile: sourcePath) else {
        print("skipping \(shot.file) — not found at \(sourcePath)")
        continue
    }

    let canvas = NSImage(size: size)
    canvas.lockFocus()

    let full = NSRect(origin: .zero, size: size)
    NSGradient(
        starting: NSColor(calibratedRed: 0.36, green: 0.64, blue: 1.00, alpha: 1),
        ending: NSColor(calibratedRed: 0.07, green: 0.24, blue: 0.72, alpha: 1)
    )?.draw(in: full, angle: -90)

    draw(shot.headline,
         font: .systemFont(ofSize: 104, weight: .bold),
         color: .white,
         centeredIn: NSRect(x: 200, y: 0, width: size.width - 400, height: 0),
         y: size.height - 250)

    draw(shot.sub,
         font: .systemFont(ofSize: 46, weight: .regular),
         color: NSColor.white.withAlphaComponent(0.82),
         centeredIn: NSRect(x: 300, y: 0, width: size.width - 600, height: 0),
         y: size.height - 350)

    // Scale the window to fill the lower area without ever upscaling past 2×,
    // which would show the interpolation.
    let available = NSSize(width: size.width * 0.62, height: size.height * 0.58)
    let scale = min(
        available.width / screenshot.size.width,
        available.height / screenshot.size.height,
        2.0
    )
    let drawn = NSSize(
        width: screenshot.size.width * scale,
        height: screenshot.size.height * scale
    )
    let target = NSRect(
        x: (size.width - drawn.width) / 2,
        y: 150,
        width: drawn.width,
        height: drawn.height
    )

    NSGraphicsContext.current?.cgContext.setShadow(
        offset: CGSize(width: 0, height: -30),
        blur: 90,
        color: NSColor.black.withAlphaComponent(0.45).cgColor
    )
    screenshot.draw(in: target)

    canvas.unlockFocus()

    guard
        let tiff = canvas.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else { continue }
    let out = "\(outputDirectory)/\(String(format: "%02d", index + 1))-\(shot.file)"
    try png.write(to: URL(fileURLWithPath: out))
    print("wrote \(out)")
}
