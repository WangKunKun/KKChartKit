import UIKit

/// Strict, whole-chain geometry. Missing samples cut ALL participating series in the stack;
/// marker/hit data remain untouched. No independent-boundary fallback is used in this mode.
enum LineDivergingStackGeometry {
    typealias Geometry = LineStackedAreaGeometry
    typealias Edge = Geometry.Edge
    struct Result {
        var contours: [Int: Geometry.Contour] = [:]
        var linearFallbackSeries: Set<Int> = []
    }

    static func contours(model: CartesianChartModel, theme: CartesianChartTheme,
                         drawValues: [[Double]], baseValues: [[Double]],
                         maximumPieces: Int = LinePercentAreaNormalizer.maximumPieces,
                         includes: (Int) -> Bool, point: (Double, Double, Int) -> CGPoint) -> Result {
        guard model.isStacked, model.maxPointCount > 0,
              theme.stackedAreaBoundaryMode == .diverging else { return Result() }
        let indices = model.series.indices.filter {
            model.series[$0].isVisible && model.series[$0].participatesInStack && includes($0)
        }
        var result = Result()
        for group in Dictionary(grouping: indices, by: { model.stackKey(for: $0) }).values {
            let percent = model.stacking == .percent
            // A ragged tail is missing, not an invented zero sample. Work only on observed
            // common runs, even when a series requests connectNulls or a permissive gap policy.
            let count = group.map { model.series[$0].data.count }.max() ?? 0
            let validity = (0..<count).map { i -> Double in
                guard group.allSatisfy({ s in
                    model.series[s].data.indices.contains(i) && model.series[s].data[i].isFinite
                        && drawValues[s].indices.contains(i) && drawValues[s][i].isFinite
                        && baseValues[s][i].isFinite
                }) else { return .nan }
                // Match the numeric percentage domain. An all-zero/unsafe sample is a break,
                // not an arbitrary bridge from 100% to a fabricated zero-height area.
                if percent && !group.contains(where: { abs(baseValues[$0][i]) > 0 }) { return .nan }
                return 1
            }
            let runs = LineMinMaxSampler.segments(values: validity, connectNulls: false)
            let axis = model.series[group[0]].effectiveYAxisIndex
            func map(_ x: Double, _ y: Double) -> CGPoint { point(x, y, axis) }
            let scale = abs(map(0, 1).y - map(0, 0).y)
            // Automatic percentages interpolate raw magnitudes before normalization. Scale
            // the entire chain uniformly to keep huge inputs away from control-net overflow.
            let magnitude = percent ? group.flatMap { model.series[$0].data }.filter(\.isFinite).map(abs).max() ?? 1 : 1
            let sources = group.map { s in
                percent ? model.series[s].data.map { $0 / max(magnitude, Double.leastNormalMagnitude) } : baseValues[s]
            }
            let built = build(group: group, runs: runs, model: model, theme: theme,
                drawValues: drawValues, values: sources, percent: percent, linear: false,
                maximumPieces: maximumPieces, scale: scale, point: map)
            // A bounded, explicit safety mode: normalize endpoints on a common straight
            // contribution mesh, then share linear boundaries (including one-sided zero limits).
            // This preserves raw samples, signs, 100% extent and shared seams,
            // rather than reverting individual series to unrelated cumulative curves.
            let resolved: [Geometry.Contour]
            if let built { resolved = built }
            else {
                result.linearFallbackSeries.formUnion(group)
                resolved = build(group: group, runs: runs, model: model, theme: theme,
                    drawValues: drawValues, values: sources, percent: percent,
                    linear: true, maximumPieces: maximumPieces, scale: scale, point: map)
                    ?? group.map { _ in Geometry.Contour(segments: []) }
            }
            for (s, contour) in zip(group, resolved) { result.contours[s] = contour }
        }
        return result
    }

    /// Conservative automatic-axis envelope: mixed staircases/curves can have an
    /// inter-sample stack larger than either endpoint stack. Each monotone contribution
    /// stays within its own endpoint range, so the sum of those ranges safely bounds it.
    /// Explicit axis bounds and user Y zoom still take precedence in the renderer.
    static func valueBounds(model: CartesianChartModel, baseValues: [[Double]],
                            includes: (Int) -> Bool) -> [Int: (min: Double, max: Double)] {
        // An entirely empty input has no prepared numeric rows, even if it has series metadata.
        guard model.isStacked, baseValues.count == model.series.count else { return [:] }
        let indices = model.series.indices.filter {
            model.series[$0].isVisible && model.series[$0].participatesInStack && includes($0)
        }
        var result: [Int: (min: Double, max: Double)] = [:]
        for group in Dictionary(grouping: indices, by: { model.stackKey(for: $0) }).values {
            let count = group.map { min(model.series[$0].data.count, baseValues[$0].count) }.min() ?? 0
            guard count > 1 else { continue }
            let axis = model.series[group[0]].effectiveYAxisIndex
            var bounds = result[axis] ?? (min: 0, max: 0)
            for i in 0..<(count - 1) {
                guard group.allSatisfy({ s in
                    model.series[s].data[i].isFinite && model.series[s].data[i + 1].isFinite
                        && baseValues[s][i].isFinite && baseValues[s][i + 1].isFinite
                }) else { continue }
                var low = 0.0, high = 0.0
                for s in group {
                    low += min(0, baseValues[s][i], baseValues[s][i + 1])
                    high += max(0, baseValues[s][i], baseValues[s][i + 1])
                }
                if model.stacking == .percent {
                    low = low < 0 ? -100 : 0; high = high > 0 ? 100 : 0
                }
                if low.isFinite { bounds.min = min(bounds.min, low) }
                if high.isFinite { bounds.max = max(bounds.max, high) }
            }
            result[axis] = bounds
        }
        return result
    }

    private static func build(group: [Int], runs: [[Int]], model: CartesianChartModel,
                              theme: CartesianChartTheme, drawValues: [[Double]], values: [[Double]],
                              percent: Bool, linear: Bool, maximumPieces: Int, scale: CGFloat,
                              point: (Double, Double) -> CGPoint) -> [Geometry.Contour]? {
        var output = group.map { _ in [Geometry.Segment]() }, budget = maximumPieces
        for run in runs {
            let raw = group.indices.map { s in Geometry.Segment(indices: run,
                points: run.map { CGPoint(x: Double($0), y: values[s][$0]) },
                style: linear ? .straight : model.series[group[s]].lineTheme(theme).lineConnectionStyle) }
            let anchors = group.map { s in run.map { point(Double($0), drawValues[s][$0]) } }
            var strokes = group.map { _ in [Edge]() }, areas = group.map { _ in [Geometry.AreaPiece]() }
            var offsets = group.map { _ in [0] }
            for i in 0..<max(0, run.count - 1) {
                let primitives = raw.map { LineDivergingStackMesh.roots(Array($0.edges[$0.offsets[i]..<$0.offsets[i + 1]])) }
                guard let slices = LineDivergingStackMesh.slices(primitives, percent: percent,
                    linearPercent: linear && percent, pixelsPerPercent: scale, budget: &budget) else { return nil }
                for s in group.indices {
                    var previousPositive = values[s][run[i]] >= 0
                    var last = strokes[s].last?.end ?? anchors[s][i]
                    for slice in slices[s] {
                        var top = mapped(slice.top, point: point)
                        let baseline = mapped(slice.baseline, point: point)
                        if last != top.start {
                            if previousPositive == slice.positive && last.x == top.start.x {
                                strokes[s].append(Edge(start: last, end: top.start, controls: nil))
                            } else { top.startsSubpath = true }
                        }
                        strokes[s].append(top)
                        areas[s].append(.init(top: [mapped(slice.top, point: point)], baseline: [baseline]))
                        last = top.end; previousPositive = slice.positive
                    }
                    let end = anchors[s][i + 1], positive = values[s][run[i + 1]] >= 0
                    if last != end {
                        let moves = previousPositive != positive || last.x != end.x
                        strokes[s].append(Edge(start: moves ? end : last,
                            end: end, controls: nil, startsSubpath: moves))
                    }
                    offsets[s].append(strokes[s].count)
                }
            }
            for s in group.indices {
                output[s].append(.init(indices: run, points: anchors[s], edges: strokes[s],
                    offsets: offsets[s], areaPieces: areas[s]))
            }
        }
        return output.map { Geometry.Contour(segments: $0) }
    }

    private static func mapped(_ edge: Edge, point: (Double, Double) -> CGPoint) -> Edge {
        func p(_ v: CGPoint) -> CGPoint { point(Double(v.x), Double(v.y)) }
        return Edge(start: p(edge.start), end: p(edge.end), controls: edge.controls.map { (p($0.0), p($0.1)) })
    }
}
