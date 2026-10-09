import UIKit

/// Percent normalization belongs to a complete mathematical stack, not an individual layer.
/// Incompatible gap topology, mixed boundary modes or singular denominators fall back atomically.
enum LinePercentStackedAreaGeometry {
    typealias Geometry = LineStackedAreaGeometry
    typealias Edge = Geometry.Edge

    static func contours(model: CartesianChartModel, theme: CartesianChartTheme,
                         drawValues: [[Double]], baseValues: [[Double]],
                         includes: (Int) -> Bool, point: (Double, Double, Int) -> CGPoint) -> [Int: Geometry.Contour] {
        guard model.stacking == .percent else { return [:] }
        let indices = model.series.indices.filter {
            let s = model.series[$0]
            return s.isVisible && !s.data.isEmpty && s.participatesInStack && includes($0)
        }
        let groups = Dictionary(grouping: indices) { model.stackKey(for: $0) }
        let interval = model.timeAxis.flatMap { $0.isValid(count: model.maxPointCount) ? $0.interval : nil }
        var result: [Int: Geometry.Contour] = [:]
        for group in groups.values {
            guard group.allSatisfy({
                let t = model.series[$0].lineTheme(theme)
                return t.showsArea && t.stackedAreaBoundaryMode == .followBaseline
            }) else { continue }
            let runs = group.map { s in
                LineMinMaxSampler.segments(values: baseValues[s], connectNulls: model.series[s].connectNulls,
                    gapPolicy: model.series[s].gapPolicy, sampleInterval: interval)
            }
            guard let common = runs.first, !common.isEmpty, runs.allSatisfy({ $0 == common }),
                  common.joined().allSatisfy({ i in group.reduce(0.0) { $0 + abs(baseValues[$1][i]) } > 1e-9 }) else { continue }
            let axis = model.series[group[0]].effectiveYAxisIndex
            let scale = abs(point(0, 1, axis).y - point(0, 0, axis).y)
            guard let built = build(group: group, runs: common, model: model, theme: theme,
                                    drawValues: drawValues, baseValues: baseValues,
                                    pixelsPerPercent: scale, point: { point($0, $1, axis) }) else { continue }
            for (s, contour) in zip(group, built) { result[s] = contour }
        }
        return result
    }

    private static func build(group: [Int], runs: [[Int]], model: CartesianChartModel, theme: CartesianChartTheme,
                              drawValues: [[Double]], baseValues: [[Double]], pixelsPerPercent: CGFloat,
                              point: (Double, Double) -> CGPoint) -> [Geometry.Contour]? {
        var result = group.map { _ in [Geometry.Segment]() }, budget = LinePercentAreaNormalizer.maximumPieces
        for run in runs {
            let raw = group.map { s in Geometry.Segment(indices: run,
                points: run.map { CGPoint(x: Double($0), y: baseValues[s][$0]) },
                style: model.series[s].lineTheme(theme).lineConnectionStyle) }
            let points = group.map { s in run.map { point(Double($0), drawValues[s][$0]) } }
            var strokes = group.map { _ in [Edge]() }, areas = group.map { _ in [Geometry.AreaPiece]() }
            var offsets = group.map { _ in [0] }
            for i in 0..<max(0, run.count - 1) {
                let primitives = raw.map { splitRoots(Array($0.edges[$0.offsets[i]..<$0.offsets[i + 1]])) }
                guard primitives.allSatisfy({ !$0.isEmpty }) else { return nil }
                let knots = Set(primitives.flatMap { $0.flatMap { [$0.start.x, $0.end.x] } }).sorted()
                var cursor = group.map { _ in 0 }, slices = group.map { _ in [LinePercentAreaNormalizer.Slice]() }
                for (a, b) in zip(knots, knots.dropFirst()) {
                    var sources: [Edge] = []
                    for s in group.indices {
                        while cursor[s] + 1 < primitives[s].count && primitives[s][cursor[s]].end.x <= a { cursor[s] += 1 }
                        let edge = primitives[s][cursor[s]]
                        guard edge.start.x <= a, edge.end.x >= b else { return nil }
                        sources.append(Geometry.portion(edge, from: a, to: b))
                    }
                    guard LinePercentAreaNormalizer.append(sources, pixelsPerPercent: pixelsPerPercent,
                        budget: &budget, into: &slices) else { return nil }
                }
                for s in group.indices {
                    var previousPositive = baseValues[group[s]][run[i]] >= 0
                    var last = strokes[s].last?.end ?? points[s][i]
                    for slice in slices[s] {
                        var top = mapped(slice.top, point: point)
                        let baseline = mapped(slice.baseline, point: point)
                        if last != top.start {
                            if previousPositive == slice.positive {
                                strokes[s].append(Edge(start: last, end: top.start, controls: nil))
                            } else { top.startsSubpath = true }
                        }
                        strokes[s].append(top)
                        areas[s].append(.init(top: [mapped(slice.top, point: point)], baseline: [baseline]))
                        last = top.end; previousPositive = slice.positive
                    }
                    // Staircase jumps at an original endpoint retain its sample anchor. Zero
                    // belongs to the positive chain even if the preceding lobe was negative.
                    let end = points[s][i + 1], positive = baseValues[group[s]][run[i + 1]] >= 0
                    if last != end {
                        strokes[s].append(Edge(start: previousPositive == positive ? last : end,
                            end: end, controls: nil, startsSubpath: previousPositive != positive))
                    }
                    offsets[s].append(strokes[s].count)
                }
            }
            for s in group.indices {
                result[s].append(.init(indices: run, points: points[s], edges: strokes[s], offsets: offsets[s], areaPieces: areas[s]))
            }
        }
        return result.map { Geometry.Contour(segments: $0) }
    }

    private static func splitRoots(_ edges: [Edge]) -> [Edge] {
        edges.filter { $0.end.x > $0.start.x }.flatMap { edge -> [Edge] in
            if edge.start.y * edge.end.y < 0,
               let halves = LineStackedAreaTransitions.splitAtZero([edge]) { return halves.0 + halves.1 }
            return [edge]
        }
    }

    private static func mapped(_ edge: Edge, point: (Double, Double) -> CGPoint) -> Edge {
        func p(_ value: CGPoint) -> CGPoint { point(Double(value.x), Double(value.y)) }
        return Edge(start: p(edge.start), end: p(edge.end), controls: edge.controls.map { (p($0.0), p($0.1)) })
    }
}
