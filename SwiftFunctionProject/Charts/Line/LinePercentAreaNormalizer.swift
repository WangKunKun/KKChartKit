import UIKit

/// A common cubic mesh for rational percentage boundaries. All layers use the same cuts
/// and denominator, so their cubic control nets share seams and sum to 100 in magnitude.
enum LinePercentAreaNormalizer {
    typealias Geometry = LineStackedAreaGeometry
    typealias Edge = Geometry.Edge
    struct Slice {
        let top: Edge
        let baseline: Edge
        let positive: Bool
    }
    /// Screen-point bound per cumulative boundary, not a fixed number of curve samples.
    static let tolerance: CGFloat = 0.05
    static let maximumPieces = 16_384

    static func append(_ sources: [Edge], pixelsPerPercent: CGFloat, depth: Int = 0,
                       budget: inout Int, into output: inout [[Slice]]) -> Bool {
        let values = sources.map(ordinates)
        // Use the dominant ordinate, not an absolute epsilon: a tiny negative layer
        // is still negative. The largest ordinate also ignores root-rounding residue.
        let signs = values.map { ($0.max(by: { abs($0) < abs($1) }) ?? 0) >= 0 }
        // Zero-root splitting and monotone interpolation give one sign per control net.
        // Reject unexpected overshoot rather than silently changing a finite contribution.
        guard zip(values, signs).allSatisfy({ values, positive in
            values.allSatisfy { $0.isFinite && (positive ? $0 >= -1e-9 : $0 <= 1e-9) }
        }) else { return false }
        let magnitudes = values.map { $0.map(abs) }
        let denominators = (0..<4).map { c in magnitudes.reduce(CGFloat(0)) { $0 + $1[c] } }
        guard let low = denominators.min(), let high = denominators.max(), low > 1e-12 else { return false }
        var positive = [CGFloat](repeating: 0, count: 4), negative = positive
        var tops: [[CGFloat]] = [], bases: [[CGFloat]] = [], maximumRange: CGFloat = 0
        for s in sources.indices {
            let base = signs[s] ? positive : negative
            let top = (0..<4).map { c in base[c] + (signs[s] ? 1 : -1) * magnitudes[s][c] / denominators[c] * 100 }
            bases.append(base); tops.append(top)
            maximumRange = max(maximumRange, top.max()! - top.min()!, base.max()! - base.min()!)
            if signs[s] { positive = top } else { negative = top }
        }
        // Rational boundary R = E[D*P]/E[D]; polynomial approximation Q = E[P].
        // |R-Q| = |Cov(D,P)|/E[D] <= range(D)*range(P)/(4*min(D)).
        // Bernstein basis functions are nonnegative and sum to one, so this bounds all t.
        let error = (high - low) / (4 * low) * maximumRange * pixelsPerPercent
        if error > tolerance {
            guard depth < 12 else { return false }
            let mid = (sources[0].start.x + sources[0].end.x) / 2
            let left = sources.map { Geometry.portion($0, from: $0.start.x, to: mid) }
            let right = sources.map { Geometry.portion($0, from: mid, to: $0.end.x) }
            return append(left, pixelsPerPercent: pixelsPerPercent, depth: depth + 1, budget: &budget, into: &output)
                && append(right, pixelsPerPercent: pixelsPerPercent, depth: depth + 1, budget: &budget, into: &output)
        }
        guard budget > 0 else { return false }
        budget -= 1
        let a = sources[0].start.x, b = sources[0].end.x
        for s in sources.indices {
            output[s].append(Slice(top: edge(tops[s], from: a, to: b),
                                   baseline: edge(bases[s], from: a, to: b), positive: signs[s]))
        }
        return true
    }

    private static func ordinates(_ edge: Edge) -> [CGFloat] {
        let a = edge.start.y, b = edge.end.y
        return [a, edge.controls?.0.y ?? (a + (b - a) / 3), edge.controls?.1.y ?? (b - (b - a) / 3), b]
    }

    private static func edge(_ ys: [CGFloat], from a: CGFloat, to b: CGFloat) -> Edge {
        Edge(start: CGPoint(x: a, y: ys[0]), end: CGPoint(x: b, y: ys[3]), controls: (
            CGPoint(x: a + (b - a) / 3, y: ys[1]), CGPoint(x: b - (b - a) / 3, y: ys[2])))
    }
}
