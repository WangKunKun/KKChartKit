import UIKit

/// Internal, per-draw contour cache. Reuse actual source primitives instead of re-interpolating
/// a subset of its points (which changes monotone tangents at the new endpoints).
enum LineStackedAreaGeometry {
    struct Edge {
        let start: CGPoint
        let end: CGPoint
        let controls: (CGPoint, CGPoint)?
        var startsSubpath = false

        func append(to path: UIBezierPath, reversed: Bool = false) {
            if startsSubpath { path.move(to: reversed ? end : start) }
            if let controls {
                path.addCurve(to: reversed ? start : end,
                              controlPoint1: reversed ? controls.1 : controls.0,
                              controlPoint2: reversed ? controls.0 : controls.1)
            } else { path.addLine(to: reversed ? start : end) }
        }
    }

    struct AreaPiece {
        let top: [Edge]
        let baseline: [Edge]

        func append(to path: UIBezierPath) {
            guard let first = top.first, let last = baseline.last else { return }
            path.move(to: first.start)
            for edge in top { edge.append(to: path) }
            path.addLine(to: last.end)
            for edge in baseline.reversed() { edge.append(to: path, reversed: true) }
            path.close()
        }
    }

    struct Segment {
        let indices: [Int]
        let points: [CGPoint]
        let edges: [Edge]
        /// Offsets into `edges` at each original data point, including staircase verticals.
        let offsets: [Int]
        /// Present when own/source sign transitions need exact interval baselines.
        let areaPieces: [AreaPiece]?
        /// One entry per original interval; nil sides indicate an unresolved source surface.
        let signEnvelopes: [LineStackedAreaSignEnvelope]?

        init(indices: [Int], points: [CGPoint], edges: [Edge], offsets: [Int], areaPieces: [AreaPiece]? = nil,
             signEnvelopes: [LineStackedAreaSignEnvelope]? = nil) {
            self.indices = indices; self.points = points
            self.edges = edges; self.offsets = offsets
            self.areaPieces = areaPieces
            self.signEnvelopes = signEnvelopes
        }

        init(indices: [Int], points: [CGPoint], style: LineConnectionStyle) {
            self.indices = indices; self.points = points
            self.areaPieces = nil
            self.signEnvelopes = nil
            var edges: [Edge] = [], offsets = [0]
            if style == .smooth, let first = points.first {
                let curve = UIBezierPath(); curve.move(to: first)
                CartesianGeometry.appendSmoothCurve(to: curve, points: points)
                var current = first
                curve.cgPath.applyWithBlock { pointer in
                    let element = pointer.pointee
                    switch element.type {
                    case .addCurveToPoint:
                        edges.append(.init(start: current, end: element.points[2],
                                           controls: (element.points[0], element.points[1])))
                        current = element.points[2]; offsets.append(edges.count)
                    case .addLineToPoint:
                        edges.append(.init(start: current, end: element.points[0], controls: nil))
                        current = element.points[0]; offsets.append(edges.count)
                    default: break
                    }
                }
            } else {
                for (a, b) in zip(points, points.dropFirst()) {
                    let step = CartesianGeometry.steppedScreenPoints([a, b], style: style)
                    for (p, q) in zip(step, step.dropFirst()) {
                        edges.append(.init(start: p, end: q, controls: nil))
                    }
                    offsets.append(edges.count)
                }
            }
            self.edges = edges; self.offsets = offsets
        }

        func append(to path: UIBezierPath) {
            guard let first = points.first else { return }
            path.move(to: first)
            for edge in edges { edge.append(to: path) }
        }
    }

    struct Slice {
        let indices: ArraySlice<Int>
        let edges: ArraySlice<Edge>
    }

    struct Contour {
        let segments: [Segment]
        private let locations: [Int: (segment: Int, point: Int)]

        init(indices: [[Int]], points: [[CGPoint]], style: LineConnectionStyle) {
            self.init(segments: zip(indices, points).map { Segment(indices: $0, points: $1, style: style) })
        }

        init(segments: [Segment]) {
            self.segments = segments
            var locations: [Int: (segment: Int, point: Int)] = [:]
            for (s, segment) in segments.enumerated() {
                for (p, index) in segment.indices.enumerated() { locations[index] = (s, p) }
            }
            self.locations = locations
        }

        var path: UIBezierPath {
            let path = UIBezierPath()
            for segment in segments { segment.append(to: path) }
            return path
        }

        /// Never cross a source's gap break, or invent a curve at an absent source point.
        func slice(from first: Int, through last: Int) -> Slice? {
            guard let a = locations[first], let b = locations[last],
                  a.segment == b.segment, a.point < b.point else { return nil }
            let segment = segments[a.segment]
            let edges = segment.edges[segment.offsets[a.point]..<segment.offsets[b.point]]
            guard !edges.contains(where: \.startsSubpath) else { return nil }
            return .init(indices: segment.indices[a.point...b.point],
                         edges: edges)
        }

        /// A source may cross zero several times while its positive/negative surfaces remain
        /// continuous. Require original endpoints and one gap-policy segment, as for slice.
        func signSlice(from first: Int, through last: Int, positive: Bool) -> [Edge]? {
            guard let a = locations[first], let b = locations[last],
                  a.segment == b.segment, a.point < b.point,
                  let envelopes = segments[a.segment].signEnvelopes else { return nil }
            var result: [Edge] = []
            for interval in a.point..<b.point {
                guard let edges = positive ? envelopes[interval].positive : envelopes[interval].negative else { return nil }
                result.append(contentsOf: edges)
            }
            return result
        }
    }

    /// Only borrow a boundary when both endpoints belong to the same sign chain and every
    /// intervening source sample belongs to it. Missing source endpoints/breaks are not invented.
    private static func sharedBaseline(series: Int, left: Int, right: Int, base: [Double],
                                       model: CartesianChartModel, drawValues: [[Double]],
                                       rawValues: [[Double]], contours: [Int: Contour]) -> Slice? {
        let raw = rawValues[series]
        let a = raw.indices.contains(left) ? raw[left] : 0
        let b = raw.indices.contains(right) ? raw[right] : 0
        let positive = a >= 0 && b >= 0, negative = a <= 0 && b <= 0
        guard positive || negative else { return nil }
        let key = model.stackKey(for: series)
        for previous in (0..<series).reversed() {
            guard model.stackKey(for: previous) == key,
                  right < model.series[previous].data.count,
                  let slice = contours[previous]?.slice(from: left, through: right),
                  matches(drawValues[previous][left], base[left]),
                  matches(drawValues[previous][right], base[right]),
                  slice.indices.allSatisfy({ index in
                      let value = rawValues[previous][index]
                      return value.isFinite && (positive ? value >= 0 : value <= 0)
                  }) else { continue }
            return slice
        }
        return nil
    }

    /// Add an interpolated, same-sign thickness to the exact lower boundary. The sum of
    /// piecewise linear/cubic functions is exact; no flattening, sampling or value clamping.
    static func followingBaseline(_ contour: Contour, series: Int, base: [Double],
                                  style: LineConnectionStyle, model: CartesianChartModel,
                                  drawValues: [[Double]], rawValues: [[Double]],
                                  contours: [Int: Contour], point: (Int, Double) -> CGPoint) -> Contour {
        let segments = contour.segments.map { segment -> Segment in
            let thickness = Segment(indices: segment.indices,
                points: zip(segment.indices, segment.points).map { index, top in
                    CGPoint(x: top.x, y: top.y - point(index, base[index]).y)
                }, style: style)
            var edges: [Edge] = [], offsets = [0], pieces: [AreaPiece] = []
            var envelopes: [LineStackedAreaSignEnvelope] = []
            var didSplit = false
            for (i, pair) in zip(segment.indices, segment.indices.dropFirst()).enumerated() {
                let delta = Array(thickness.edges[thickness.offsets[i]..<thickness.offsets[i + 1]])
                let raw = rawValues[series]
                let positive = signBaseline(series: series, left: pair.0, right: pair.1, positive: true,
                    model: model, drawValues: drawValues, rawValues: rawValues, contours: contours, point: point)
                let negative = signBaseline(series: series, left: pair.0, right: pair.1, positive: false,
                    model: model, drawValues: drawValues, rawValues: rawValues, contours: contours, point: point)
                let startsPositive = (raw.indices.contains(pair.0) ? raw[pair.0] : 0) >= 0
                let sameSign = startsPositive == ((raw.indices.contains(pair.1) ? raw[pair.1] : 0) >= 0)
                if raw.indices.contains(pair.1), raw[pair.0].isFinite, raw[pair.1].isFinite,
                   !sameSign, let positive, let negative,
                   let lobes = LineStackedAreaTransitions.split(thickness: delta, positive: positive,
                       negative: negative, startsPositive: raw[pair.0] >= 0) {
                    didSplit = true
                    envelopes.append(LineStackedAreaSignEnvelope.crossing(thickness: delta, positive: positive,
                        negative: negative, startsPositive: startsPositive) ?? .init(positive: nil, negative: nil))
                    pieces.append(contentsOf: lobes)
                    for (lobe, piece) in lobes.enumerated() {
                        var top = piece.top
                        // A sign-chain jump is a move, never a line through the lower layers.
                        if lobe > 0 { top[0].startsSubpath = true }
                        edges.append(contentsOf: top)
                    }
                } else {
                    let source = sharedBaseline(series: series, left: pair.0, right: pair.1,
                        base: base, model: model, drawValues: drawValues, rawValues: rawValues, contours: contours)
                    let resolved = sameSign ? (startsPositive ? positive : negative) : nil
                    let baseline = resolved ?? source.map { Array($0.edges) } ?? [Edge(
                        start: point(pair.0, base[pair.0]), end: point(pair.1, base[pair.1]), controls: nil)]
                    let composed = (resolved ?? source.map { Array($0.edges) }).flatMap { adding($0, delta) }
                    let top = composed
                        ?? Array(segment.edges[segment.offsets[i]..<segment.offsets[i + 1]])
                    if resolved != nil, composed != nil { didSplit = true }
                    edges.append(contentsOf: top)
                    pieces.append(AreaPiece(top: top, baseline: baseline))
                    // Do not publish a guessed surface after an unresolved transition.
                    envelopes.append(.init(positive: sameSign && startsPositive && resolved != nil ? composed : (sameSign && !startsPositive ? positive : nil),
                                           negative: sameSign && !startsPositive && resolved != nil ? composed : (sameSign && startsPositive ? negative : nil)))
                }
                offsets.append(edges.count)
            }
            return Segment(indices: segment.indices, points: segment.points, edges: edges, offsets: offsets,
                           areaPieces: didSplit ? pieces : nil, signEnvelopes: envelopes)
        }
        return Contour(segments: segments)
    }

    /// Both paths run left to right. Vertical stair edges are retained at their original X;
    /// other edges are split at the union of knots before adding their Y coordinates.
    static func adding(_ base: [Edge], _ thickness: [Edge]) -> [Edge]? {
        guard var p = base.first?.start, var q = thickness.first?.start,
              p.x == q.x, base.last?.end.x == thickness.last?.end.x else { return nil }
        var a = 0, b = 0, result: [Edge] = []
        func sum(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: p.x, y: p.y + q.y) }
        while a < base.count || b < thickness.count {
            if a < base.count, base[a].start.x == base[a].end.x {
                let end = base[a].end
                result.append(Edge(start: sum(p, q), end: sum(end, q), controls: nil))
                p = end; a += 1; continue
            }
            if b < thickness.count, thickness[b].start.x == thickness[b].end.x {
                let end = thickness[b].end
                result.append(Edge(start: sum(p, q), end: sum(p, end), controls: nil))
                q = end; b += 1; continue
            }
            guard a < base.count, b < thickness.count else { return nil }
            let x = min(base[a].end.x, thickness[b].end.x)
            let lower = portion(base[a], from: p.x, to: x)
            let delta = portion(thickness[b], from: q.x, to: x)
            let controls: (CGPoint, CGPoint)?
            if lower.controls == nil && delta.controls == nil { controls = nil }
            else {
                let lc = cubicControls(lower), dc = cubicControls(delta)
                controls = (sum(lc.0, dc.0), sum(lc.1, dc.1))
            }
            result.append(Edge(start: sum(lower.start, delta.start), end: sum(lower.end, delta.end), controls: controls))
            p = lower.end; q = delta.end
            if x == base[a].end.x { a += 1 }
            if x == thickness[b].end.x { b += 1 }
        }
        return result
    }

    private static func cubicControls(_ edge: Edge) -> (CGPoint, CGPoint) {
        if let controls = edge.controls { return controls }
        return (CGPoint(x: edge.start.x + (edge.end.x - edge.start.x) / 3,
                        y: edge.start.y + (edge.end.y - edge.start.y) / 3),
                CGPoint(x: edge.end.x - (edge.end.x - edge.start.x) / 3,
                        y: edge.end.y - (edge.end.y - edge.start.y) / 3))
    }

    /// Our monotone cubics have linear X(t). Restrict a polynomial without changing its shape.
    static func portion(_ edge: Edge, from x0: CGFloat, to x1: CGFloat) -> Edge {
        if x0 == edge.start.x && x1 == edge.end.x { return edge }
        let width = edge.end.x - edge.start.x
        let t0 = (x0 - edge.start.x) / width, t1 = (x1 - edge.start.x) / width
        let controls = cubicControls(edge)
        let y0 = edge.start.y, y1 = controls.0.y, y2 = controls.1.y, y3 = edge.end.y
        func value(_ t: CGFloat) -> CGFloat {
            let u = 1 - t
            return u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3
        }
        func slope(_ t: CGFloat) -> CGFloat {
            let u = 1 - t
            return 3 * (u * u * (y1 - y0) + 2 * u * t * (y2 - y1) + t * t * (y3 - y2))
        }
        let start = CGPoint(x: x0, y: value(t0)), end = CGPoint(x: x1, y: value(t1))
        return Edge(start: start, end: end, controls: edge.controls == nil ? nil : (
            CGPoint(x: x0 + (x1 - x0) / 3, y: start.y + slope(t0) * (t1 - t0) / 3),
            CGPoint(x: x1 - (x1 - x0) / 3, y: end.y - slope(t1) * (t1 - t0) / 3)))
    }

    /// Preserve known parts of a broken source instead of discarding the entire long interval.
    private static func signBaseline(series: Int, left: Int, right: Int, positive: Bool,
                                     model: CartesianChartModel, drawValues: [[Double]],
                                     rawValues: [[Double]], contours: [Int: Contour],
                                     point: (Int, Double) -> CGPoint) -> [Edge]? {
        func continuous(_ a: Int, _ b: Int) -> [Edge]? {
            continuousSignBaseline(series: series, left: a, right: b, positive: positive,
                model: model, drawValues: drawValues, rawValues: rawValues, contours: contours, point: point)
        }
        if let boundary = continuous(left, right) { return boundary }
        let previous = (0..<series).filter { model.series[$0].isVisible && model.stackKey(for: $0) == model.stackKey(for: series) }
        guard previous.contains(where: { s in
            (left...right).contains { !rawValues[s].indices.contains($0) || !rawValues[s][$0].isFinite }
        }) else { return nil }
        return LineStackedAreaGapBaseline.resolve(from: left, through: right,
            sources: previous.compactMap { contours[$0] }, continuous: continuous) { index in
                let base = previous.reduce(0.0) { sum, s in
                    guard rawValues[s].indices.contains(index) else { return sum }
                    let value = rawValues[s][index]
                    return sum + (value.isFinite && (positive ? value >= 0 : value < 0) ? value : 0)
                }
                return point(index, base)
            }
    }

    /// Resolve each sign chain using an actual continuous source contour or an empty chain.
    /// The gap resolver calls this per subinterval; it must never recursively bridge a gap.
    private static func continuousSignBaseline(series: Int, left: Int, right: Int, positive: Bool,
                                               model: CartesianChartModel, drawValues: [[Double]],
                                               rawValues: [[Double]], contours: [Int: Contour],
                                               point: (Int, Double) -> CGPoint) -> [Edge]? {
        let previous = (0..<series).filter { model.series[$0].isVisible && model.stackKey(for: $0) == model.stackKey(for: series) }
        func contribution(_ s: Int, _ i: Int) -> Double {
            guard rawValues[s].indices.contains(i) else { return 0 }
            let value = rawValues[s][i]
            return value.isFinite && (positive ? value >= 0 : value < 0) ? value : 0
        }
        let a = previous.reduce(0.0) { $0 + contribution($1, left) }
        let b = previous.reduce(0.0) { $0 + contribution($1, right) }
        // The latest surface already includes every earlier layer in this mathematical stack.
        // Never use an earlier cached surface across a later layer's unresolved gap/transition.
        if let last = previous.last,
           let boundary = contours[last]?.signSlice(from: left, through: right, positive: positive),
           let start = boundary.first?.start, let end = boundary.last?.end,
           abs(start.y - point(left, a).y) < 1e-7, abs(end.y - point(right, b).y) < 1e-7 {
            return boundary
        }
        for s in previous.reversed() {
            guard right < model.series[s].data.count,
                  previous.filter({ $0 > s }).allSatisfy({ later in
                      (left...right).allSatisfy { contribution(later, $0) == 0 }
                  }),
                  let slice = contours[s]?.slice(from: left, through: right),
                  matches(drawValues[s][left], a), matches(drawValues[s][right], b),
                  slice.indices.allSatisfy({ i in
                      let value = rawValues[s][i]
                      return value.isFinite && (positive ? value >= 0 : value <= 0)
                  }) else { continue }
            return Array(slice.edges)
        }
        guard previous.allSatisfy({ s in (left...right).allSatisfy { contribution(s, $0) == 0 } }) else { return nil }
        return [Edge(start: point(left, 0), end: point(right, 0), controls: nil)]
    }

    /// Return along exact shared source edges. A transition with no common source is a straight
    /// connector between the original stack bases, not a claim of seamless continuous stacking.
    static func appendBaseline(to path: UIBezierPath, series: Int, indices: [Int], base: [Double],
                               model: CartesianChartModel, drawValues: [[Double]], rawValues: [[Double]],
                               contours: [Int: Contour], point: (Int, Double) -> CGPoint) {
        guard let last = indices.last else { return }
        path.addLine(to: point(last, base[last]))
        for (left, right) in zip(indices, indices.dropFirst()).reversed() {
            let shared = sharedBaseline(series: series, left: left, right: right, base: base,
                model: model, drawValues: drawValues, rawValues: rawValues, contours: contours)
            if let shared, let end = shared.edges.last?.end {
                // Keep the source's exact endpoint too (stack subtraction may round differently).
                path.addLine(to: end)
                for edge in shared.edges.reversed() { edge.append(to: path, reversed: true) }
            } else {
                path.addLine(to: point(right, base[right]))
                path.addLine(to: point(left, base[left]))
            }
        }
    }

    private static func matches(_ a: Double, _ b: Double) -> Bool {
        a.isFinite && b.isFinite && abs(a - b) <= max(1, max(abs(a), abs(b))) * 1e-12
    }
}
