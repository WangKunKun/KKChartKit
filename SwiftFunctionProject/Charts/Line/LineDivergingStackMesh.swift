import UIKit

/// A common X mesh for both sign chains. Raw contribution curves are cut at their own
/// zero crossings BEFORE stacking, never replaced by endpoint-only positive/negative copies.
enum LineDivergingStackMesh {
    typealias Geometry = LineStackedAreaGeometry
    typealias Edge = Geometry.Edge
    typealias Slice = LinePercentAreaNormalizer.Slice

    static func roots(_ edges: [Edge]) -> [Edge] {
        edges.filter { $0.end.x > $0.start.x }.flatMap { edge -> [Edge] in
            if (edge.start.y < 0 && edge.end.y > 0) || (edge.start.y > 0 && edge.end.y < 0),
               let halves = LineStackedAreaTransitions.splitAtZero([edge]) {
                return halves.0 + halves.1
            }
            return [edge]
        }
    }

    static func slices(_ primitives: [[Edge]], percent: Bool, linearPercent: Bool = false, pixelsPerPercent: CGFloat,
                       budget: inout Int) -> [[Slice]]? {
        guard primitives.allSatisfy({ !$0.isEmpty }) else { return nil }
        let knots = Set(primitives.flatMap { $0.flatMap { [$0.start.x, $0.end.x] } }).sorted()
        var cursors = primitives.map { _ in 0 }, result = primitives.map { _ in [Slice]() }
        for (a, b) in zip(knots, knots.dropFirst()) {
            var sources: [Edge] = []
            for s in primitives.indices {
                while cursors[s] + 1 < primitives[s].count && primitives[s][cursors[s]].end.x <= a {
                    cursors[s] += 1
                }
                let edge = primitives[s][cursors[s]]
                guard edge.start.x <= a, edge.end.x >= b else { return nil }
                sources.append(Geometry.portion(edge, from: a, to: b))
            }
            if percent && sources.allSatisfy({ e in
                e.start.y == 0 && e.end.y == 0 && (e.controls?.0.y ?? 0) == 0 && (e.controls?.1.y ?? 0) == 0
            }) { continue } // No defined ratio over this entire slab; neither area nor connecting stroke.
            if percent && linearPercent {
                appendLinearPercent(sources, into: &result)
            } else if percent {
                guard LinePercentAreaNormalizer.append(removingCommonZeroFactors(sources), pixelsPerPercent: pixelsPerPercent,
                    budget: &budget, into: &result) else { return nil }
            } else {
                var positive = Edge(start: CGPoint(x: a, y: 0), end: CGPoint(x: b, y: 0), controls: nil)
                var negative = positive
                for s in sources.indices {
                    let source = sources[s]
                    let ordinates = [source.start.y, source.controls?.0.y ?? source.start.y,
                                     source.controls?.1.y ?? source.end.y, source.end.y]
                    // An identically zero interval belongs to the positive chain.
                    let isPositive = ordinates.reduce(0) { $0 + $1 / 4 } >= 0
                    let baseline = isPositive ? positive : negative
                    guard let top = Geometry.adding([baseline], [source])?.first else { return nil }
                    result[s].append(Slice(top: top, baseline: baseline, positive: isPositive))
                    if isPositive { positive = top } else { negative = top }
                }
            }
        }
        return result
    }


    /// Cancel a common t or (1-t) factor in Bernstein form before rational normalization.
    /// This gives finite one-sided percentage limits at simultaneous zero crossings without
    /// inventing a data point, clamping a denominator, or changing the curve in the interval.
    private static func removingCommonZeroFactors(_ sources: [Edge]) -> [Edge] {
        var values = sources.map { e -> [CGFloat] in
            [e.start.y, e.controls?.0.y ?? (e.start.y + (e.end.y - e.start.y) / 3),
             e.controls?.1.y ?? (e.end.y - (e.end.y - e.start.y) / 3), e.end.y]
        }
        var degree = 3
        while degree > 0 {
            let atStart = values.allSatisfy { $0[0] == 0 }
            let atEnd = values.allSatisfy { $0[degree] == 0 }
            guard atStart || atEnd else { break }
            var reduced: [[CGFloat]] = []
            for row in values {
                var next: [CGFloat] = []
                for i in 0..<degree {
                    let divisor = atStart ? i + 1 : degree - i
                    let factor = CGFloat(degree) / CGFloat(divisor)
                    next.append(row[atStart ? i + 1 : i] * factor)
                }
                reduced.append(next)
            }
            values = reduced; degree -= 1
        }
        guard degree < 3 else { return sources }
        while degree < 3 {
            var elevated: [[CGFloat]] = []
            for row in values {
                var next = [row[0]]
                for i in 1..<(degree + 1) {
                    let weight = CGFloat(i) / CGFloat(degree + 1)
                    next.append(weight * row[i - 1] + (1 - weight) * row[i])
                }
                next.append(row[degree]); elevated.append(next)
            }
            values = elevated; degree += 1
        }
        return zip(sources, values).map { e, v in
            let a = e.start.x, b = e.end.x
            return Edge(start: CGPoint(x: a, y: v[0]), end: CGPoint(x: b, y: v[3]), controls: (
                CGPoint(x: a + (b - a) / 3, y: v[1]), CGPoint(x: b - (b - a) / 3, y: v[2])))
        }
    }

    /// Budget-independent percentage fallback. Normalize endpoints on each sign-stable
    /// interval, using the one-sided ratio limit if every contribution vanishes there.
    /// The shared linear control net still sums to 100 in absolute magnitude everywhere.
    private static func appendLinearPercent(_ sources: [Edge], into output: inout [[Slice]]) {
        let values = sources.map { edge -> [CGFloat] in
            let a = edge.start.y, b = edge.end.y
            return [a, edge.controls?.0.y ?? (a + (b - a) / 3),
                    edge.controls?.1.y ?? (b - (b - a) / 3), b]
        }
        let totals = (0..<4).map { i in values.reduce(CGFloat(0)) { $0 + abs($1[i]) } }
        // Only identically-zero intervals have no one-sided ratio; they have no area.
        guard let first = totals.firstIndex(where: { $0 > 0 }),
              let last = totals.lastIndex(where: { $0 > 0 }) else { return }
        var positive = [CGFloat](repeating: 0, count: 2), negative = positive
        for s in sources.indices {
            let isPositive = values[s].reduce(0) { $0 + $1 / 4 } >= 0
            let base = isPositive ? positive : negative
            let weights = [values[s][first] / totals[first] * 100, values[s][last] / totals[last] * 100]
            let top = zip(base, weights).map(+)
            func edge(_ ys: [CGFloat]) -> Edge {
                Edge(start: CGPoint(x: sources[s].start.x, y: ys[0]),
                     end: CGPoint(x: sources[s].end.x, y: ys[1]), controls: nil)
            }
            output[s].append(Slice(top: edge(top), baseline: edge(base), positive: isPositive))
            if isPositive { positive = top } else { negative = top }
        }
    }
}
