import UIKit

/// Geometric zero crossings only: no inserted data samples, indices or hit targets.
/// A lobe closes on its own sign chain; the stroke moves between distinct chain baselines.
enum LineStackedAreaTransitions {
    private typealias Geometry = LineStackedAreaGeometry
    typealias Edge = LineStackedAreaGeometry.Edge
    typealias AreaPiece = LineStackedAreaGeometry.AreaPiece

    static func split(thickness: [Edge], positive: [Edge], negative: [Edge],
                      startsPositive: Bool) -> [AreaPiece]? {
        guard let first = thickness.first, let last = thickness.last,
              let halves = splitAtZero(thickness),
              let leftEnd = halves.0.last?.end, let rightStart = halves.1.first?.start else { return nil }
        let before = clipped(startsPositive ? positive : negative, from: first.start.x, to: leftEnd.x)
        let after = clipped(startsPositive ? negative : positive, from: rightStart.x, to: last.end.x)
        guard let leftTop = Geometry.adding(before, halves.0),
              let rightTop = Geometry.adding(after, halves.1) else { return nil }
        return [AreaPiece(top: leftTop, baseline: before), AreaPiece(top: rightTop, baseline: after)]
    }

    /// Monotone contribution curves cross at most once in an original sample interval.
    /// Staircase verticals use the same split, including jumps at either endpoint.
    static func splitAtZero(_ edges: [Edge]) -> ([Edge], [Edge])? {
        for (i, edge) in edges.enumerated() {
            let a = edge.start.y, b = edge.end.y
            guard a == 0 || b == 0 || (a < 0) != (b < 0) else { continue }
            let t: CGFloat
            if a == 0 { t = 0 }
            else if b == 0 { t = 1 }
            else if edge.controls == nil { t = abs(a) / (abs(a) + abs(b)) }
            else {
                var lo: CGFloat = 0, hi: CGFloat = 1
                for _ in 0..<56 {
                    let mid = (lo + hi) / 2
                    if (value(edge, at: mid).y < 0) == (a < 0) { lo = mid } else { hi = mid }
                }
                t = (lo + hi) / 2
            }
            let pair = divided(edge, at: t)
            return (Array(edges.prefix(i)) + [pair.0], [pair.1] + Array(edges.dropFirst(i + 1)))
        }
        return nil
    }

    private static func blend(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private static func value(_ edge: Edge, at t: CGFloat) -> CGPoint {
        // Keep exact endpoints: subtracting a large off-screen X can otherwise move a zero
        // endpoint just past the interval, which is invalid for an endpoint staircase cut.
        if t == 0 { return edge.start }
        if t == 1 { return edge.end }
        guard let c = edge.controls else { return blend(edge.start, edge.end, t) }
        let a = blend(edge.start, c.0, t), b = blend(c.0, c.1, t), d = blend(c.1, edge.end, t)
        return blend(blend(a, b, t), blend(b, d, t), t)
    }

    private static func divided(_ edge: Edge, at t: CGFloat) -> (Edge, Edge) {
        var zero = value(edge, at: t); zero.y = 0
        guard let c = edge.controls else {
            return (Edge(start: edge.start, end: zero, controls: nil), Edge(start: zero, end: edge.end, controls: nil))
        }
        let a = blend(edge.start, c.0, t), b = blend(c.0, c.1, t), d = blend(c.1, edge.end, t)
        return (Edge(start: edge.start, end: zero, controls: (a, blend(a, b, t))),
                Edge(start: zero, end: edge.end, controls: (blend(b, d, t), d)))
    }

    /// Include verticals at the cut: a staircase may change both baseline and thickness there.
    /// Zero-width lobes retain their original endpoint as stroke geometry, with no filled area.
    private static func clipped(_ edges: [Edge], from lo: CGFloat, to hi: CGFloat) -> [Edge] {
        guard lo <= hi else { return [] }
        var result: [Edge] = []
        for edge in edges {
            if edge.start.x == edge.end.x {
                if (lo...hi).contains(edge.start.x) { result.append(edge) }
            } else {
                let a = max(lo, edge.start.x), b = min(hi, edge.end.x)
                if a < b { result.append(Geometry.portion(edge, from: a, to: b)) }
            }
        }
        if result.isEmpty, let edge = edges.first(where: { $0.start.x <= lo && $0.end.x >= lo }) {
            let p = edge.start.x == edge.end.x ? edge.start : Geometry.portion(edge, from: lo, to: lo).start
            result = [Edge(start: p, end: p, controls: nil)]
        }
        return result
    }
}
