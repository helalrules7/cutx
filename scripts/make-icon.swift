// Renders Resources/AppIcon.icns source images.
//
// Standalone by design: it duplicates the scissors geometry from
// Sources/CutX/ScissorsShape.swift rather than importing the app target, so the
// icon can be regenerated with plain swiftc and no package build.
//
// Usage: swiftc -O scripts/make-icon.swift -o /tmp/render && /tmp/render <outdir>

import AppKit

let out = CommandLine.arguments[1]
let sizes = [16, 32, 64, 128, 256, 512, 1024]

/// Apple's icon silhouette is a superellipse, not a rounded rectangle. The
/// difference is subtle at a glance and obvious side by side.
func squircle(in r: CGRect, n: CGFloat = 5.0) -> NSBezierPath {
    let p = NSBezierPath()
    let a = r.width / 2, b = r.height / 2
    let cx = r.midX, cy = r.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2/n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2/n) * (st < 0 ? -1 : 1)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.line(to: CGPoint(x: x, y: y)) }
    }
    p.close()
    return p
}

/// One blade: a tapered quadrilateral from the pivot out to a point, plus the
/// handle arm and its ring. Filled shapes rather than uniform strokes — that
/// taper is most of what separates an app icon from a wireframe.
func blade(pivot: CGPoint, tip: CGPoint, width: CGFloat) -> NSBezierPath {
    let dx = tip.x - pivot.x, dy = tip.y - pivot.y
    let len = max(sqrt(dx*dx + dy*dy), 0.001)
    let nx = -dy/len, ny = dx/len            // unit normal
    let base = width / 2
    let p = NSBezierPath()
    p.move(to: CGPoint(x: pivot.x + nx*base, y: pivot.y + ny*base))
    // Cutting edge stays straight; the back of the blade curves.
    p.line(to: CGPoint(x: tip.x, y: tip.y))
    p.curve(to: CGPoint(x: pivot.x - nx*base, y: pivot.y - ny*base),
            controlPoint1: CGPoint(x: pivot.x - nx*base*0.2 + dx*0.55,
                                   y: pivot.y - ny*base*0.2 + dy*0.55),
            controlPoint2: CGPoint(x: pivot.x - nx*base*1.1 + dx*0.18,
                                   y: pivot.y - ny*base*1.1 + dy*0.18))
    p.close()
    return p
}

func ring(center: CGPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    p.appendOval(in: CGRect(x: center.x-outer, y: center.y-outer, width: outer*2, height: outer*2))
    p.appendOval(in: CGRect(x: center.x-inner, y: center.y-inner, width: inner*2, height: inner*2))
    p.windingRule = .evenOdd
    return p
}

/// Returns the solid parts and the ring parts separately: they need different
/// fill rules, and overlapping them in one path is what produces the notches
/// where an arm crosses a ring.
func glyph(in r: CGRect, open: Bool) -> (solid: NSBezierPath, rings: NSBezierPath) {
    let w = r.width, h = r.height, cx = r.midX
    let pivot = CGPoint(x: cx, y: r.minY + h * 0.42)
    let loopR = w * 0.145, innerR = loopR * 0.52
    let loopY = r.minY + h * 0.13
    let loopDX = w * 0.205
    let tipDX = open ? w * 0.21 : w * 0.045
    let tipY = r.minY + h * 0.96
    let armW = w * 0.105

    let solid = NSBezierPath()
    let rings = NSBezierPath()
    rings.windingRule = .evenOdd

    for side in [CGFloat(-1), 1] {
        let loop = CGPoint(x: cx + loopDX * side, y: loopY)
        let tip = CGPoint(x: cx - tipDX * side, y: tipY)
        solid.append(blade(pivot: pivot, tip: tip, width: w * 0.135))

        // Stop the arm at the ring's edge so it never crosses the hole.
        let dx = pivot.x - loop.x, dy = pivot.y - loop.y
        let len = max(sqrt(dx*dx + dy*dy), 0.001)
        let attach = CGPoint(x: loop.x + dx/len * loopR * 0.85,
                             y: loop.y + dy/len * loopR * 0.85)
        let arm = NSBezierPath()
        arm.move(to: attach)
        arm.line(to: pivot)
        solid.append(NSBezierPath(cgPath: arm.cgPathStroked(width: armW)))

        rings.append(ring(center: loop, outer: loopR, inner: innerR))
    }
    return (solid, rings)
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &points) {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
    func cgPathStroked(width: CGFloat) -> CGPath {
        cgPath.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }
    convenience init(cgPath: CGPath) {
        self.init()
        cgPath.applyWithBlock { el in
            let p = el.pointee.points
            switch el.pointee.type {
            case .moveToPoint: self.move(to: p[0])
            case .addLineToPoint: self.line(to: p[0])
            case .addQuadCurveToPoint: self.curve(to: p[1], controlPoint1: p[0], controlPoint2: p[0])
            case .addCurveToPoint: self.curve(to: p[2], controlPoint1: p[0], controlPoint2: p[1])
            case .closeSubpath: self.close()
            @unknown default: break
            }
        }
    }
}

for size in sizes {
    let side = CGFloat(size)
    let img = NSImage(size: NSSize(width: side, height: side))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let tile = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: side*0.055, dy: side*0.055)
    let tilePath = squircle(in: tile)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -side*0.012), blur: side*0.03,
                  color: NSColor.black.withAlphaComponent(0.28).cgColor)
    NSColor.white.setFill(); tilePath.fill()
    ctx.restoreGState()

    ctx.saveGState()
    tilePath.addClip()
    NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.64, blue: 1.00, alpha: 1),
               ending: NSColor(calibratedRed: 0.09, green: 0.30, blue: 0.85, alpha: 1))?
        .draw(in: tile, angle: -90)
    // A sheen across the top half, the way physical glass catches light.
    NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.20), 0.0),
        (NSColor.white.withAlphaComponent(0.0), 1.0))?
        .draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height/2), angle: -90)
    ctx.restoreGState()

    let g = tile.insetBy(dx: tile.width*0.22, dy: tile.height*0.20)
    let parts = glyph(in: g, open: true)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -side*0.006), blur: side*0.016,
                  color: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.4, alpha: 0.45).cgColor)
    NSColor.white.setFill()
    parts.solid.fill()
    parts.rings.fill()
    ctx.restoreGState()

    // Pivot screw, knocked out in the tile color so it reads as hardware.
    let pr = g.width * 0.042
    let pc = CGPoint(x: g.midX, y: g.minY + g.height*0.42)
    NSColor(calibratedRed: 0.16, green: 0.40, blue: 0.90, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: pc.x-pr, y: pc.y-pr, width: pr*2, height: pr*2)).fill()

    img.unlockFocus()
    if let t = img.tiffRepresentation, let rep = NSBitmapImageRep(data: t),
       let png = rep.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: "\(out)/icon_\(size).png"))
    }
}
