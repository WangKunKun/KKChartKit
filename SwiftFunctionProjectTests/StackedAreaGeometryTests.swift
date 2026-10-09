import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class StackedAreaGeometryTests: XCTestCase {
    private struct Edge: Equatable {
        let start: CGPoint
        let end: CGPoint
        let controls: [CGPoint]
        var reversed: Edge { .init(start: end, end: start, controls: controls.reversed()) }
    }

    private func edges(_ path: CGPath) -> [Edge] {
        var result: [Edge] = [], current = CGPoint.zero
        path.applyWithBlock { pointer in
            let e = pointer.pointee
            switch e.type {
            case .moveToPoint: current = e.points[0]
            case .addLineToPoint:
                result.append(.init(start: current, end: e.points[0], controls: [])); current = e.points[0]
            case .addCurveToPoint:
                result.append(.init(start: current, end: e.points[2], controls: [e.points[0], e.points[1]])); current = e.points[2]
            default: break
            }
        }
        return result
    }

    private func chart(_ data: [[Double]], styles: [LineConnectionStyle], connects: [Bool] = [],
                       boundary: StackedAreaBoundaryMode = .independent) -> HYMChartView<LineChartRenderer> {
        let series = data.enumerated().map { i, values in
            var style = CartesianSeriesStyle()
            style.lineConnectionStyle = styles[i]; style.showsPoints = false; style.showsArea = true
            style.areaGradientColors = [[UIColor.blue], [.orange], [.green]][i % 3]
            return CartesianSeriesElement(name: "S\(i)", data: values, color: [.blue, .orange, .green][i % 3],
                connectNulls: connects.indices.contains(i) ? connects[i] : false,
                style: style)
        }
        let v = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
        var theme = CartesianChartTheme(); theme.stackedAreaBoundaryMode = boundary
        v.configure(model: .init(series: series, stacking: .normal), theme: theme)
        v.layoutIfNeeded()
        return v
    }

    private func area(_ view: HYMChartView<LineChartRenderer>, _ series: Int) throws -> CGPath {
        let gradients = view.rendererForTesting.seriesLayer.sublayers!.compactMap { $0 as? CAGradientLayer }
        return try XCTUnwrap((gradients[series].mask as? CAShapeLayer)?.path)
    }

    private func assertSharedEdges(_ view: HYMChartView<LineChartRenderer>, source: Int, target: Int,
                                   indices: ClosedRange<Int>, file: StaticString = #filePath, line: UInt = #line) throws {
        let r = view.rendererForTesting
        let lowerTop = edges(try area(view, source)).filter { $0.end.x > $0.start.x }
        let upperBottom = edges(try area(view, target)).filter { $0.end.x < $0.start.x }
        let x0 = r.testScreenPoint(series: source, index: indices.lowerBound).x
        let x1 = r.testScreenPoint(series: source, index: indices.upperBound).x
        let expected = lowerTop.filter { $0.start.x >= x0 && $0.end.x <= x1 }
        XCTAssertFalse(expected.isEmpty, file: file, line: line)
        for edge in expected {
            XCTAssertTrue(upperBottom.contains(edge.reversed), "Missing exact reversed source edge: \(edge)", file: file, line: line)
        }
    }

    func testUpperGapMustNotRecomputeLowerSmoothTangents() throws {
        let v = chart([[10, 40, 20, 70, 30, 60], [5, .nan, 5, 5, 5, 5]], styles: [.smooth, .smooth])
        try assertSharedEdges(v, source: 0, target: 1, indices: 2...5)
    }

    func testSourceSignChangeOnlyAffectsTheTransitionInterval() throws {
        let v = chart([[10, 12, 14, 16, 18, 20, 22], [20, 40, 10, -10, -20, -5, -10], Array(repeating: 8, count: 7)],
                      styles: [.smooth, .smooth, .straight])
        try assertSharedEdges(v, source: 1, target: 2, indices: 0...2)
        try assertSharedEdges(v, source: 0, target: 2, indices: 3...6)
    }

    func testSourceGapMustNotChangeNeighboringSharedCurves() throws {
        let v = chart([[10, 12, 14, 16, 18, 20, 22], [20, 40, 10, .nan, 20, 50, 10], Array(repeating: 8, count: 7)],
                      styles: [.smooth, .smooth, .smooth])
        try assertSharedEdges(v, source: 1, target: 2, indices: 0...2)
        try assertSharedEdges(v, source: 1, target: 2, indices: 4...6)
    }

    func testConnectedUpperGapFollowsAllIntermediateLowerVertices() throws {
        let v = chart([[10, 40, 20, 70, 30, 60], [5, .nan, .nan, 5, 5, 5]],
                      styles: [.smooth, .straight], connects: [false, true])
        try assertSharedEdges(v, source: 0, target: 1, indices: 0...5)
    }

    func testAllConnectionStylesAndStackModesShareExactNegativeAndPositiveEdges() throws {
        let modes: [StackConfig] = [.normal, .percent, .percentFixed(max: 200), .grouped(groupCount: 1)]
        for style in LineConnectionStyle.allCases {
            for mode in modes {
                for sign in [1.0, -1.0] {
                    let v = chart([[10, 40, 20, 70, 30, 60].map { $0 * sign },
                                   [5, .nan, 5, 5, 5, 5].map { $0 * sign }], styles: [style, .smooth])
                    var m = v.rendererForTesting.currentModel!; m.stacking = mode
                    v.update(model: m); v.layoutIfNeeded()
                    try assertSharedEdges(v, source: 0, target: 1, indices: 2...5)
                    if style == .stepBefore || style == .stepAfter || style == .stepCenter {
                        let top = edges(try area(v, 0)), bottom = edges(try area(v, 1))
                        let x0 = v.rendererForTesting.testScreenPoint(series: 0, index: 2).x
                        let x1 = v.rendererForTesting.testScreenPoint(series: 0, index: 5).x
                        let verticals = top.filter { $0.start.x == $0.end.x && $0.start.x > x0 && $0.start.x < x1 && $0.start.y != $0.end.y }
                        XCTAssertFalse(verticals.isEmpty)
                        for edge in verticals { XCTAssertTrue(bottom.contains(edge.reversed)) }
                    }
                }
            }
        }
    }

    func testBrokenSourceUsesStraightTransitionInsteadOfInventingSmoothBridge() throws {
        let v = chart([[10, 40, .nan, 70, 30, 60], [5, .nan, .nan, 5, 5, 5]],
                      styles: [.smooth, .smooth], connects: [false, true])
        let r = v.rendererForTesting
        let a = r.testScreenPoint(series: 0, index: 0), b = r.testScreenPoint(series: 0, index: 3)
        XCTAssertTrue(edges(try area(v, 1)).contains(.init(start: b, end: a, controls: [])))
        try assertSharedEdges(v, source: 0, target: 1, indices: 3...5)
    }

    func testSourceCrossingOppositeSignInsideConnectedUpperGapIsNotBorrowed() throws {
        let v = chart([[20, -50, -30, 40, 50], [5, .nan, .nan, 5, 5]],
                      styles: [.smooth, .smooth], connects: [false, true])
        let r = v.rendererForTesting
        let a = r.testScreenPoint(series: 0, index: 0), b = r.testScreenPoint(series: 0, index: 3)
        XCTAssertTrue(edges(try area(v, 1)).contains(.init(start: b, end: a, controls: [])))
        let negative = r.testScreenPoint(series: 0, index: 1)
        XCTAssertFalse(edges(try area(v, 1)).filter { $0.end.x < $0.start.x }.contains { $0.start == negative || $0.end == negative })
    }

    func testRaggedHiddenIndependentAndSecondaryAxisSeriesRemainFinite() throws {
        let v = chart([[10, 20], [5, .nan, -5, 20], [0, 0, 0, 0, 0, 0]], styles: [.smooth, .stepCenter, .smooth])
        for mode: StackConfig in [.normal, .percent, .percentFixed(max: 100), .grouped(groupCount: 2)] {
            for independent in [false, true] {
                var m = v.rendererForTesting.currentModel!; m.stacking = mode
                m.secondaryYAxis = .init(kind: .value)
                m.series[1].yAxisIndex = 1; m.series[1].participatesInStack = !independent
                m.series[0].isVisible = !independent
                v.update(model: m); v.layoutIfNeeded()
                let paths = v.rendererForTesting.seriesLayer.sublayers!.compactMap { ($0 as? CAGradientLayer)?.mask as? CAShapeLayer }.compactMap(\.path)
                XCTAssertFalse(paths.isEmpty)
                for path in paths {
                    for edge in edges(path) {
                        for point in [edge.start, edge.end] + edge.controls {
                            XCTAssertTrue(point.x.isFinite && point.y.isFinite)
                        }
                    }
                }
                XCTAssertEqual(v.rendererForTesting.datum(series: 1, category: 3)?.stackBase, 0)
            }
        }
    }

    func testLiveStyleAndVisibilityUpdatesRebuildContoursAndPreserveViewport() throws {
        let v = chart([[10, 40, 20, 70, 30, 60], [50, .nan, 50, 50, 50, 50]], styles: [.smooth, .smooth])
        v.showCategoryRange(2..<5); v.layoutIfNeeded()
        let domain = v.rendererForTesting.currentViewport.xDomain
        var m = v.rendererForTesting.currentModel!
        m.series[0].style.lineConnectionStyle = .stepBefore
        v.update(model: m, viewportPolicy: .preserve); v.layoutIfNeeded()
        XCTAssertEqual(v.rendererForTesting.currentViewport.xDomain, domain)
        try assertSharedEdges(v, source: 0, target: 1, indices: 2...5)
        m.series[0].isVisible = false
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(v.rendererForTesting.datum(series: 1, category: 3)?.stackBase, 0)
        m.series[0].isVisible = true; m.series[0].data = [15, 45, 25, 75, 35, 65]
        v.update(model: m); v.layoutIfNeeded()
        try assertSharedEdges(v, source: 0, target: 1, indices: 2...5)
        let point = v.rendererForTesting.testScreenPoint(series: 1, index: 3)
        let hit = try XCTUnwrap(v.rendererForTesting.seriesHitTest(point) as? LineHitTarget)
        XCTAssertEqual(hit.rawValue, 50); XCTAssertEqual(hit.stackBase, 75)
        v.update(model: m, viewportPolicy: .reset); v.layoutIfNeeded()
        XCTAssertNotEqual(v.rendererForTesting.currentViewport.xDomain, domain)
    }

    func testSharedCurveFillHasNeitherGapNorOverlapAndSavesImageEvidence() throws {
        let v = chart([[10, 40, 20, 70, 30, 60], [50, .nan, 50, 50, 50, 50]], styles: [.smooth, .smooth])
        let lower = try area(v, 0), upper = try area(v, 1)
        let x0 = v.rendererForTesting.testScreenPoint(series: 0, index: 2).x
        let forward = edges(lower).filter { $0.end.x > $0.start.x && $0.start.x >= x0 }
        var probes = 0
        for edge in forward {
            for t: CGFloat in [0.25, 0.5, 0.75] {
                let c = edge.controls
                let points = c.isEmpty ? [edge.start, edge.end] : [edge.start] + c + [edge.end]
                var blend = points
                while blend.count > 1 {
                    blend = zip(blend, blend.dropFirst()).map { a, b in
                        CGPoint(x: a.x * (1 - t) + b.x * t, y: a.y * (1 - t) + b.y * t)
                    }
                }
                let p = blend[0], above = CGPoint(x: p.x, y: p.y - 0.1), below = CGPoint(x: p.x, y: p.y + 0.1)
                XCTAssertTrue(upper.contains(above)); XCTAssertFalse(lower.contains(above))
                XCTAssertTrue(lower.contains(below)); XCTAssertFalse(upper.contains(below))
                probes += 1
            }
        }
        XCTAssertEqual(probes, 9)
        let image = UIGraphicsImageRenderer(size: v.bounds.size).image { context in
            UIColor.white.setFill(); context.fill(v.bounds); v.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image); attachment.name = "stacked-area-shared-curves"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testSeamPresetIsAvailableInBothDemosAndKeepsOriginalHitData() {
        for kind: CartesianDemoKind in [.line, .combined] {
            var s = CartesianDemoState(kind: kind)
            s.series[0].dataText = "nan"; s.dualAxis = true; s.query = "接缝"
            s.stackedAreaSeamPreset()
            XCTAssertEqual(s.query, "接缝"); XCTAssertFalse(s.dualAxis)
            XCTAssertEqual(s.seriesCount, 3); XCTAssertEqual(s.selectedSeries, 2)
            XCTAssertEqual(s.model.maxPointCount, 12)
            XCTAssertTrue(s.model.series.allSatisfy { $0.lineTheme(s.builtTheme).showsArea })
            XCTAssertTrue(s.model.series[1].data[6].isNaN)
            XCTAssertTrue(s.model.series[2].data[8].isNaN)
            XCTAssertEqual(s.model.stackedDrawValues[2][3], 42)
            s.series[2].style.lineConnectionStyle = .stepAfter
            XCTAssertEqual(s.model.series[2].lineTheme(s.builtTheme).lineConnectionStyle, .stepAfter)
        }
    }

    func testContourMatchesOriginalStrokeGeometryForEveryConnectionStyle() {
        let points = [CGPoint(x: 0, y: 25), CGPoint(x: 10, y: 5), CGPoint(x: 30, y: 40), CGPoint(x: 45, y: 15)]
        for style in LineConnectionStyle.allCases {
            let expected = UIBezierPath(); expected.move(to: points[0])
            if style == .smooth { CartesianGeometry.appendSmoothCurve(to: expected, points: points) }
            else { for p in CartesianGeometry.steppedScreenPoints(points, style: style).dropFirst() { expected.addLine(to: p) } }
            let contour = LineStackedAreaGeometry.Contour(indices: [[0, 1, 3, 6]], points: [points], style: style)
            XCTAssertEqual(edges(contour.path.cgPath), edges(expected.cgPath))
            XCTAssertEqual(contour.path.cgPath.boundingBoxOfPath, expected.cgPath.boundingBoxOfPath)
            XCTAssertNil(contour.slice(from: 0, through: 2))
            let separated = LineStackedAreaGeometry.Contour(indices: [[0, 1], [3, 6]], points: [Array(points.prefix(2)), Array(points.suffix(2))], style: style)
            XCTAssertNil(separated.slice(from: 1, through: 3))
        }
    }

    func testThinMixedStyleAreaDoesNotFoldInsideLowerArea() throws {
        let v = chart([[10, 90, 10], [2, 2, 2]], styles: [.smooth, .straight], boundary: .followBaseline)
        let lower = try area(v, 0), upper = try area(v, 1)
        let edge = try XCTUnwrap(edges(lower).first { $0.end.x > $0.start.x })
        let c = edge.controls
        let p = CGPoint(x: (edge.start.x + edge.end.x) / 2,
                        y: (edge.start.y + 3 * c[0].y + 3 * c[1].y + edge.end.y) / 8)
        let below = CGPoint(x: p.x, y: p.y + 0.25)
        let above = CGPoint(x: p.x, y: p.y - 0.25)
        let image = UIGraphicsImageRenderer(size: v.bounds.size).image { context in
            UIColor.white.setFill(); context.fill(v.bounds); v.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image); attachment.name = "thin-mixed-style-area"
        attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertTrue(lower.contains(below)); XCTAssertFalse(upper.contains(below))
        XCTAssertFalse(lower.contains(above)); XCTAssertTrue(upper.contains(above))
    }

    func testCrossingAreaClosesOnItsOwnSignBaseline() throws {
        let v = chart([[40, 40, 40], [-30, -30, -30], [10, -10, 10]],
                      styles: [.straight, .straight, .straight], boundary: .followBaseline)
        let r = v.rendererForTesting, path = try area(v, 2)
        let image = UIGraphicsImageRenderer(size: v.bounds.size).image { context in
            UIColor.white.setFill(); context.fill(v.bounds); v.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image); attachment.name = "crossing-sign-baselines"
        attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertFalse(path.contains(r.screenPoint(x: 0.25, y: 25, yAxisIndex: 0)), "Crossing area must not fill inside the positive base")
        XCTAssertTrue(path.contains(r.screenPoint(x: 0.25, y: 42, yAxisIndex: 0)), "Positive lobe belongs above its positive base")
        XCTAssertFalse(path.contains(r.screenPoint(x: 0.75, y: -15, yAxisIndex: 0)), "Crossing area must not fill inside the negative base")
        XCTAssertTrue(path.contains(r.screenPoint(x: 0.75, y: -32, yAxisIndex: 0)), "Negative lobe belongs below its negative base")
    }

    private func assertCoverage(lower: CGPath, upper: CGPath, sign: CGFloat,
                                minX: CGFloat = -.infinity, maxX: CGFloat = .infinity,
                                file: StaticString = #filePath, line: UInt = #line) {
        var probes = 0
        for edge in edges(lower) where edge.end.x > edge.start.x && edge.start.x >= minX && edge.end.x <= maxX {
            for t: CGFloat in [0.15, 0.5, 0.85] {
                var points = [edge.start] + edge.controls + [edge.end]
                while points.count > 1 {
                    points = zip(points, points.dropFirst()).map { a, b in
                        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                    }
                }
                let p = points[0]
                let outside = CGPoint(x: p.x, y: p.y - sign * 0.02)
                let inside = CGPoint(x: p.x, y: p.y + sign * 0.02)
                XCTAssertTrue(upper.contains(outside), "Gap at \(p)", file: file, line: line)
                XCTAssertFalse(lower.contains(outside), file: file, line: line)
                XCTAssertTrue(lower.contains(inside), file: file, line: line)
                XCTAssertFalse(upper.contains(inside), "Overlap at \(p)", file: file, line: line)
                probes += 1
            }
        }
        XCTAssertGreaterThan(probes, 0, file: file, line: line)
    }

    func testFollowingBaselineCoversAllStylePairsBothSignsAndThreeStackModes() throws {
        var combinations = 0
        for lowerStyle in LineConnectionStyle.allCases {
            for upperStyle in LineConnectionStyle.allCases {
                for sign in [1.0, -1.0] {
                    for mode: StackConfig in [.normal, .percentFixed(max: 200), .grouped(groupCount: 1)] {
                        let v = chart([[10, 90, 10, 70, 30], [2, 5, 2, 3, 2], [1, 2, 1, 2, 1]].map { $0.map { $0 * sign } },
                            styles: [lowerStyle, upperStyle, .smooth], boundary: .followBaseline)
                        let r = v.rendererForTesting
                        var model = r.currentModel!; model.stacking = mode
                        v.update(model: model); v.layoutIfNeeded()
                        for target in 1...2 {
                            try assertSharedEdges(v, source: target - 1, target: target, indices: 0...4)
                            assertCoverage(lower: try area(v, target - 1), upper: try area(v, target), sign: sign)
                            for index in 0..<5 {
                                let hit = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: target, index: index)) as? LineHitTarget)
                                // Thin layers can share the hit radius; use an explicit target for data checks.
                                XCTAssertEqual(hit.index, index)
                                let datum = try XCTUnwrap(r.datum(series: target, category: index))
                                XCTAssertEqual(datum.rawValue, model.series[target].data[index])
                                XCTAssertEqual(datum.drawValue, r.currentDrawValues[target][index])
                            }
                        }
                        combinations += 1
                    }
                }
            }
        }
        XCTAssertEqual(combinations, 150)
    }

    func testFollowingBaselineConnectedGapUsesIntermediateSourceKnots() throws {
        let v = chart([[10, 90, 10, 70, 30], [2, .nan, .nan, 2, 2]], styles: [.smooth, .stepCenter],
                      connects: [false, true], boundary: .followBaseline)
        try assertSharedEdges(v, source: 0, target: 1, indices: 0...4)
        assertCoverage(lower: try area(v, 0), upper: try area(v, 1), sign: 1)
        XCTAssertTrue(v.rendererForTesting.currentModel!.series[1].data[1].isNaN)
        XCTAssertEqual(v.rendererForTesting.renderedIndices[1], [[0, 3, 4]])
    }

    func testFollowingBaselineRefinesSourceGapsAndResolvedCrossings() throws {
        for lower in [[10.0, .nan, 10, 70, 30]] {
            let v = chart([lower, [2, .nan, .nan, 2, 2]], styles: [.smooth, .straight],
                          connects: [false, true], boundary: .followBaseline)
            let r = v.rendererForTesting
            // The true gap ends at index 2. Preserve the source curve again on 2...3.
            let a = r.testScreenPoint(series: 1, index: 0)
            let b = r.screenPoint(x: 2, y: 12)
            // Endpoint mapping and baseline + thickness use different floating-point operation orders.
            // Shared source edges above still require exact equality; this derived connector uses 1e-6 pt.
            XCTAssertTrue(edges(try area(v, 1)).contains {
                $0.controls.isEmpty && hypot($0.start.x - a.x, $0.start.y - a.y) < 1e-6
                    && hypot($0.end.x - b.x, $0.end.y - b.y) < 1e-6
            })
            try assertSharedEdges(v, source: 0, target: 1, indices: 2...4)
            assertCoverage(lower: try area(v, 0), upper: try area(v, 1), sign: 1,
                           minX: r.testScreenPoint(series: 0, index: 3).x)
        }
        let v = chart([[10, -90, 10], [2, -2, 2]], styles: [.smooth, .straight])
        let before = edges(try area(v, 1))
        var theme = v.rendererForTesting.currentTheme!; theme.stackedAreaBoundaryMode = .followBaseline
        v.update(model: v.rendererForTesting.currentModel!, theme: theme); v.layoutIfNeeded()
        // Resolved lower sign switches now publish continuous positive/negative surfaces.
        XCTAssertNotEqual(edges(try area(v, 1)), before)
    }

    func testFollowingBaselineLiveUpdatesAndPercentEnvelopeStayCompatible() throws {
        let v = chart([[10, 90, 10], [2, 2, 2]], styles: [.smooth, .straight])
        let r = v.rendererForTesting, old = edges(try area(v, 1))
        var theme = r.currentTheme!; theme.stackedAreaBoundaryMode = .followBaseline
        v.showCategoryRange(0..<2); v.layoutIfNeeded()
        let domain = r.currentViewport.xDomain
        v.update(model: r.currentModel!, theme: theme); v.layoutIfNeeded()
        XCTAssertEqual(r.currentViewport.xDomain, domain)
        v.resetViewport(); v.layoutIfNeeded()
        XCTAssertNotEqual(edges(try area(v, 1)), old)
        assertCoverage(lower: try area(v, 0), upper: try area(v, 1), sign: 1)
        let model = r.currentModel!
        v.setSeriesVisible(false, for: model.series[0].id); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 1, category: 1)?.stackBase, 0)
        v.setSeriesVisible(true, for: model.series[0].id); v.layoutIfNeeded()
        assertCoverage(lower: try area(v, 0), upper: try area(v, 1), sign: 1)
        var percent = model; percent.stacking = .percent
        v.update(model: percent, theme: theme); v.layoutIfNeeded()
        let percentPath = edges(try area(v, 1))
        XCTAssertEqual(r.datum(series: 1, category: 1)?.drawValue, 100)
        theme.stackedAreaBoundaryMode = .independent
        v.update(model: percent, theme: theme); v.layoutIfNeeded()
        XCTAssertNotEqual(edges(try area(v, 1)), percentPath)
        v.update(model: model, theme: theme); v.layoutIfNeeded()
        XCTAssertEqual(edges(try area(v, 1)), old)
    }

    func testFollowingBaselineCombinedAndOCBridgeDrawSameBoundaries() throws {
        var state = CartesianDemoState(kind: .combined); state.thinStackedAreaPreset()
        let model = state.model, theme = state.builtTheme
        let line = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
        let combined = HYMChartView<CombinedChartRenderer>(frame: line.frame)
        line.configure(model: model, theme: theme); line.layoutIfNeeded()
        combined.configure(model: model, theme: theme); combined.layoutIfNeeded()
        func paths(_ layer: CALayer) -> [CGPath] {
            if let gradient = layer as? CAGradientLayer, let path = (gradient.mask as? CAShapeLayer)?.path { return [path] }
            return (layer.sublayers ?? []).flatMap(paths)
        }
        let combinedPaths = paths(combined.rendererForTesting.rootLayer)
        XCTAssertEqual(combinedPaths.count, 3)
        for i in 0..<3 { XCTAssertEqual(edges(combinedPaths[i]), edges(try area(line, i))) }
        let source = HYMCartesianModel(); source.stacking = .normal
        source.series = [[10.0, 90, 10], [2, 2, 2]].enumerated().map { i, data in
            let s = HYMCartesianSeries(); s.identifier = "s\(i)"; s.name = "S\(i)"
            s.data = data.map(NSNumber.init(value:)); s.kind = i == 0 ? .areaspline : .area
            return s
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: line.frame)
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let oc = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        let before = edges(try area(oc, 1))
        bridge.stackedAreaFollowsBaseline = true
        try bridge.update(model: source, preserveViewport: true); bridge.chartView.layoutIfNeeded()
        XCTAssertNotEqual(edges(try area(oc, 1)), before)
        assertCoverage(lower: try area(oc, 0), upper: try area(oc, 1), sign: 1)
    }

}
