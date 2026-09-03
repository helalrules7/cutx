import AppKit

/// A pair of scissors drawn as filled shapes, in two positions.
///
/// Both states come from one construction — two tapered blades meeting at a
/// pivot, two arms, two finger rings — with only the blade angle changing. That
/// is what makes the open and closed icons read as the same object in two
/// positions rather than as two unrelated pictures.
///
/// The parts are returned separately because they need different fill rules:
/// overlapping the rings with the arms in a single even-odd path punches notches
/// wherever an arm crosses a ring.
enum ScissorsShape {
    static func parts(open: Bool, in r: CGRect) -> (solid: NSBezierPath, rings: NSBezierPath) {
        let w = r.width, h = r.height, cx = r.midX
        let pivot = CGPoint(x: cx, y: r.minY + h * 0.42)
        let loopRadius = w * 0.145
        let innerRadius = loopRadius * 0.52
        let loopY = r.minY + h * 0.13
        let loopDX = w * 0.205
        let tipDX = open ? w * 0.21 : w * 0.045
        let tipY = r.minY + h * 0.96
        let armWidth = w * 0.105

        let solid = NSBezierPath()
        let rings = NSBezierPath()
        rings.windingRule = .evenOdd

        for side in [CGFloat(-1), 1] {
            let loop = CGPoint(x: cx + loopDX * side, y: loopY)
            let tip = CGPoint(x: cx - tipDX * side, y: tipY)
            solid.append(blade(pivot: pivot, tip: tip, width: w * 0.135))

            // Stop the arm at the ring's edge so it never crosses the hole.
            let dx = pivot.x - loop.x, dy = pivot.y - loop.y
            let length = max(sqrt(dx * dx + dy * dy), 0.001)
            let attach = CGPoint(
                x: loop.x + dx / length * loopRadius * 0.85,
                y: loop.y + dy / length * loopRadius * 0.85
            )
            let arm = NSBezierPath()
            arm.move(to: attach)
            arm.line(to: pivot)
            solid.append(NSBezierPath(cgPath: arm.strokedPath(width: armWidth)))

            rings.append(ring(center: loop, outer: loopRadius, inner: innerRadius))
        }
        return (solid, rings)
    }

    static func pivot(in r: CGRect) -> (center: CGPoint, radius: CGFloat) {
        (CGPoint(x: r.midX, y: r.minY + r.height * 0.42), r.width * 0.042)
    }

    /// One blade: straight on the cutting edge, curved along the back, tapering
    /// to a point. The taper is most of what separates an icon from a wireframe.
    private static func blade(pivot: CGPoint, tip: CGPoint, width: CGFloat) -> NSBezierPath {
        let dx = tip.x - pivot.x, dy = tip.y - pivot.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let nx = -dy / length, ny = dx / length
        let base = width / 2

        let path = NSBezierPath()
        path.move(to: CGPoint(x: pivot.x + nx * base, y: pivot.y + ny * base))
        path.line(to: tip)
        path.curve(
            to: CGPoint(x: pivot.x - nx * base, y: pivot.y - ny * base),
            controlPoint1: CGPoint(
                x: pivot.x - nx * base * 0.2 + dx * 0.55,
                y: pivot.y - ny * base * 0.2 + dy * 0.55
            ),
            controlPoint2: CGPoint(
                x: pivot.x - nx * base * 1.1 + dx * 0.18,
                y: pivot.y - ny * base * 1.1 + dy * 0.18
            )
        )
        path.close()
        return path
    }

    private static func ring(center: CGPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.appendOval(in: CGRect(
            x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2
        ))
        path.appendOval(in: CGRect(
            x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2
        ))
        path.windingRule = .evenOdd
        return path
    }
}

extension NSBezierPath {
    var quartzPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }

    func strokedPath(width: CGFloat) -> CGPath {
        quartzPath.copy(
            strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10
        )
    }

    convenience init(cgPath: CGPath) {
        self.init()
        cgPath.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: self.move(to: points[0])
            case .addLineToPoint: self.line(to: points[0])
            case .addQuadCurveToPoint:
                self.curve(to: points[1], controlPoint1: points[0], controlPoint2: points[0])
            case .addCurveToPoint:
                self.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
            case .closeSubpath: self.close()
            @unknown default: break
            }
        }
    }
}
