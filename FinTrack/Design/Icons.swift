//
//  Icons.swift
//  FinTrack — Design system: Lucide-style 2px-stroke icons.
//
//  Every icon is the literal SVG geometry lifted from the prototype: a 24x24 viewBox,
//  stroke-width 2, round caps, round joins, no fill. SF Symbols are deliberately NOT used —
//  their optical metrics differ from Lucide's.
//
//  The path data below is transcribed character for character from FinTrack.dc.html and
//  rendered by a small SVG-path interpreter (M m L l H h V v C c Q q A a Z z), so no
//  geometry is re-derived by hand.
//

import SwiftUI

// MARK: - SVG path interpreter

private struct FTPathScanner {
    private let chars: [Character]
    private var i = 0

    init(_ s: String) { chars = Array(s) }

    private mutating func skipSeparators() {
        while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n"
                || chars[i] == "\t" || chars[i] == "\r" {
            i += 1
        }
    }

    mutating func nextCommand() -> Character? {
        skipSeparators()
        guard i < chars.count, chars[i].isLetter else { return nil }
        let c = chars[i]
        i += 1
        return c
    }

    mutating func peekIsNumber() -> Bool {
        skipSeparators()
        guard i < chars.count else { return false }
        let c = chars[i]
        return c.isNumber || c == "." || c == "-" || c == "+"
    }

    mutating func nextNumber() -> CGFloat? {
        skipSeparators()
        guard i < chars.count else { return nil }
        var s = ""
        if chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
        var seenDot = false
        while i < chars.count {
            let c = chars[i]
            if c.isNumber {
                s.append(c); i += 1
            } else if c == "." && !seenDot {
                seenDot = true; s.append(c); i += 1
            } else {
                break
            }
        }
        guard let v = Double(s) else { return nil }
        return CGFloat(v)
    }
}

private enum FTSVGPath {

    /// Parse an SVG `d` attribute into a Path in the 24x24 icon space.
    static func parse(_ d: String) -> Path {
        var path = Path()
        var sc = FTPathScanner(d)
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var pending: Character?

        while true {
            let cmd: Character
            if let c = sc.nextCommand() {
                cmd = c
            } else if sc.peekIsNumber(), let p = pending {
                // An implicit repeat: a further M/m coordinate pair means a line.
                cmd = (p == "M") ? "L" : (p == "m" ? "l" : p)
            } else {
                break
            }
            pending = cmd
            let rel = cmd.isLowercase
            if path.isEmpty && cmd != "M" && cmd != "m" { path.move(to: current) }

            switch cmd {
            case "M", "m":
                guard let x = sc.nextNumber(), let y = sc.nextNumber() else { return path }
                let pt = rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.move(to: pt)
                current = pt
                subpathStart = pt
            case "L", "l":
                guard let x = sc.nextNumber(), let y = sc.nextNumber() else { return path }
                let pt = rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addLine(to: pt)
                current = pt
            case "H", "h":
                guard let x = sc.nextNumber() else { return path }
                let pt = CGPoint(x: rel ? current.x + x : x, y: current.y)
                path.addLine(to: pt)
                current = pt
            case "V", "v":
                guard let y = sc.nextNumber() else { return path }
                let pt = CGPoint(x: current.x, y: rel ? current.y + y : y)
                path.addLine(to: pt)
                current = pt
            case "C", "c":
                guard let a = sc.nextNumber(), let b = sc.nextNumber(),
                      let c = sc.nextNumber(), let d2 = sc.nextNumber(),
                      let e = sc.nextNumber(), let f = sc.nextNumber() else { return path }
                let ox = rel ? current.x : 0, oy = rel ? current.y : 0
                let c1 = CGPoint(x: ox + a, y: oy + b)
                let c2 = CGPoint(x: ox + c, y: oy + d2)
                let pt = CGPoint(x: ox + e, y: oy + f)
                path.addCurve(to: pt, control1: c1, control2: c2)
                current = pt
            case "Q", "q":
                guard let a = sc.nextNumber(), let b = sc.nextNumber(),
                      let c = sc.nextNumber(), let d2 = sc.nextNumber() else { return path }
                let ox = rel ? current.x : 0, oy = rel ? current.y : 0
                let ctrl = CGPoint(x: ox + a, y: oy + b)
                let pt = CGPoint(x: ox + c, y: oy + d2)
                path.addQuadCurve(to: pt, control: ctrl)
                current = pt
            case "A", "a":
                guard let rx = sc.nextNumber(), let ry = sc.nextNumber(),
                      let rot = sc.nextNumber(), let laf = sc.nextNumber(),
                      let sf = sc.nextNumber(), let x = sc.nextNumber(),
                      let y = sc.nextNumber() else { return path }
                let pt = rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                appendArc(&path, from: current, to: pt, rx: rx, ry: ry,
                          rotationDeg: rot, largeArc: laf != 0, sweep: sf != 0)
                current = pt
            case "Z", "z":
                path.closeSubpath()
                current = subpathStart
            default:
                return path
            }
        }
        return path
    }

    /// SVG endpoint-parameterised elliptical arc -> cubic Béziers (SVG spec F.6.5 / F.6.2).
    private static func appendArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                                  rx rxIn: CGFloat, ry ryIn: CGFloat, rotationDeg: CGFloat,
                                  largeArc: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }

        let phi = rotationDeg * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1p =  cosP * dx2 + sinP * dy2
        let y1p = -sinP * dx2 + cosP * dy2

        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s
            ry *= s
        }

        let rx2 = rx * rx, ry2 = ry * ry
        let num = max(0, rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p)
        let den = rx2 * y1p * y1p + ry2 * x1p * x1p
        let coef: CGFloat = (largeArc == sweep ? -1 : 1) * (den == 0 ? 0 : sqrt(num / den))
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * (-ry * x1p / rx)
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2

        let sv = CGPoint(x: (x1p - cxp) / rx, y: (y1p - cyp) / ry)
        let ev = CGPoint(x: (-x1p - cxp) / rx, y: (-y1p - cyp) / ry)
        let theta1 = atan2(sv.y, sv.x)
        var sweepAngle = atan2(ev.y, ev.x) - theta1
        if sweep && sweepAngle < 0 { sweepAngle += 2 * .pi }
        if !sweep && sweepAngle > 0 { sweepAngle -= 2 * .pi }

        let segments = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
        let delta = sweepAngle / CGFloat(segments)
        let alpha = 4.0 / 3.0 * tan(delta / 4)

        func point(_ t: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cosP * cos(t) - ry * sinP * sin(t),
                    y: cy + rx * sinP * cos(t) + ry * cosP * sin(t))
        }
        func derivative(_ t: CGFloat) -> CGPoint {
            CGPoint(x: -rx * cosP * sin(t) - ry * sinP * cos(t),
                    y: -rx * sinP * sin(t) + ry * cosP * cos(t))
        }

        for i in 0..<segments {
            let t1 = theta1 + CGFloat(i) * delta
            let t2 = t1 + delta
            let pa = point(t1), pb = point(t2)
            let da = derivative(t1), db = derivative(t2)
            let c1 = CGPoint(x: pa.x + alpha * da.x, y: pa.y + alpha * da.y)
            let c2 = CGPoint(x: pb.x - alpha * db.x, y: pb.y - alpha * db.y)
            path.addCurve(to: pb, control1: c1, control2: c2)
        }
    }
}

// MARK: - Icon geometry

/// One primitive of an icon, in the 24x24 viewBox.
private enum FTIconPrimitive {
    case path(String)
    case circle(CGFloat, CGFloat, CGFloat)                       // cx, cy, r
    case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)       // x, y, w, h, rx
}

/// The stroked outline of an icon, normalised to a 24x24 space and scaled into `rect`.
struct FTIconShape: Shape {
    let kind: FTIcon.Kind

    func path(in rect: CGRect) -> Path {
        var unit = Path()
        for primitive in FTIconShape.primitives(kind) {
            switch primitive {
            case .path(let d):
                unit.addPath(FTSVGPath.parse(d))
            case .circle(let cx, let cy, let r):
                unit.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            case .rect(let x, let y, let w, let h, let r):
                unit.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h),
                                    cornerSize: CGSize(width: r, height: r),
                                    style: .circular)
            }
        }
        let s = min(rect.width, rect.height) / 24
        let transform = CGAffineTransform(
            translationX: rect.minX + (rect.width - 24 * s) / 2,
            y: rect.minY + (rect.height - 24 * s) / 2
        ).scaledBy(x: s, y: s)
        return unit.applying(transform)
    }

    fileprivate static func primitives(_ kind: FTIcon.Kind) -> [FTIconPrimitive] {
        switch kind {
        case .home:
            return [.path("M3 10.5 12 3l9 7.5"), .path("M5 9.5V21h14V9.5")]
        case .activity:
            return [.path("M3 12h4l3-8 4 16 3-8h4")]
        case .lock:
            return [.path("M17 9V7a5 5 0 0 0-10 0v2"), .rect(4, 9, 16, 11, 3)]
        case .chat:
            return [.path("M21 12a8 8 0 0 1-8 8H4l2-3a8 8 0 1 1 15-5z")]
        case .gear:
            return [
                .circle(12, 12, 3),
                .path("M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.01a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.01a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z")
            ]
        case .sun:
            return [
                .circle(12, 12, 4),
                .path("M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4")
            ]
        case .moon:
            return [.path("M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z")]
        case .restore:
            return [.path("M3 12a9 9 0 1 1 3 6.7"), .path("M3 22v-5h5")]
        case .chevronLeft:
            return [.path("M15 18l-6-6 6-6")]
        case .plus:
            return [.path("M12 5v14M5 12h14")]
        case .send:
            return [.path("M12 19V5M5 12l7-7 7 7")]
        }
    }
}

// MARK: - FTIcon

/// A Lucide-style stroked icon. The stroke stays visually 2pt at the natural 24pt size and
/// scales proportionally with `size`.
struct FTIcon: View {

    enum Kind: String, CaseIterable {
        case home, activity, lock, chat, gear, sun, moon, restore, chevronLeft, plus, send
    }

    let kind: Kind
    var size: CGFloat = 24
    var color: Color
    var lineWidth: CGFloat = 2

    init(kind: Kind, size: CGFloat = 24, color: Color, lineWidth: CGFloat = 2) {
        self.kind = kind
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }

    init(_ kind: Kind, size: CGFloat = 24, color: Color, lineWidth: CGFloat = 2) {
        self.init(kind: kind, size: size, color: color, lineWidth: lineWidth)
    }

    var body: some View {
        FTIconShape(kind: kind)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * (size / 24),
                                              lineCap: .round,
                                              lineJoin: .round))
            .frame(width: size, height: size)
    }
}
