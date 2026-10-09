import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class StackedAreaTransitionTests: XCTestCase {
    private struct Edge {
        let start: CGPoint
        let end: CGPoint
        let controls: [CGPoint]
        func value(_ t: CGFloat) -> CGPoint {
            var points = [start] + controls + [end]
            while points.count > 1 {
                points = zip(points, points.dropFirst()).map { a, b in
                    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                }
            }
            return points[0]
        }
    }
    private func edges(_ path: CGPath) -> [Edge] {
        var result: [Edge] = [], p = CGPoint.zero
        path.applyWithBlock { pointer in
            let e = pointer.pointee
            switch e.type {
            case .moveToPoint: p = e.points[0]
            case .addLineToPoint:
                result.append(Edge(start: p, end: e.points[0], controls: [])); p = e.points[0]
            case .addCurveToPoint:
                result.append(Edge(start: p, end: e.points[2], controls: [e.points[0], e.points[1]])); p = e.points[2]
            default: break
            }
        }
        return result
    }
    private func moves(_ path: CGPath) -> [CGPoint] {
        var result: [CGPoint] = []
        path.applyWithBlock { if $0.pointee.type == .moveToPoint { result.append($0.pointee.points[0]) } }
        return result
    }
    private func model(_ data: [[Double]], styles: [LineConnectionStyle], connects: [Bool] = [],
                       stacking: StackConfig = .normal) -> CartesianChartModel {
        .init(series: data.enumerated().map { i, values in
            var style = CartesianSeriesStyle(); style.showsArea = true; style.showsPoints = false
            style.lineConnectionStyle = styles[i]
            return .init(name: "S\(i)", data: values, color: [.blue, .orange, .green][i % 3],
                         connectNulls: connects.indices.contains(i) ? connects[i] : false,
                         id: "s\(i)", style: style)
        }, stacking: stacking)
    }
    private func chart(_ model: CartesianChartModel, mode: StackedAreaBoundaryMode = .followBaseline) -> HYMChartView<LineChartRenderer> {
        let v = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
        var theme = CartesianChartTheme(); theme.stackedAreaBoundaryMode = mode
        v.configure(model: model, theme: theme); v.layoutIfNeeded(); return v
    }
    private func area(_ r: LineChartRenderer, _ series: Int) throws -> CGPath {
        let layers = (r.seriesLayer.sublayers ?? []).compactMap { $0 as? CAGradientLayer }
        let layer = try XCTUnwrap(layers.indices.contains(series) ? layers[series] : nil, "Expected area \(series), got \(layers.count)")
        return try XCTUnwrap((layer.mask as? CAShapeLayer)?.path)
    }
    private func stroke(_ r: LineChartRenderer, _ series: Int) throws -> CGPath {
        let layers = (r.seriesLayer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.filter { $0.fillColor == nil }
        let layer = try XCTUnwrap(layers.indices.contains(series) ? layers[series] : nil, "Expected stroke \(series), got \(layers.count)")
        return try XCTUnwrap(layer.path)
    }
    private func top(_ path: CGPath, x: CGFloat) throws -> CGPoint {
        let edge = try XCTUnwrap(edges(path).first { $0.start.x < x && $0.end.x > x })
        return edge.value((x - edge.start.x) / (edge.end.x - edge.start.x))
    }

    func testCrossingStyleAndSignMatrixHasNoFillInsideEitherBaseline() throws {
        var count = 0
        let styles = LineConnectionStyle.allCases
        for (i, baseStyle) in styles.enumerated() {
            for style in styles {
                for sign in [1.0, -1.0] {
                    for mode: StackConfig in [.normal, .percentFixed(max: 200), .grouped(groupCount: 1)] {
                        let v = chart(model([[40, 80, 30, 60], [-30, -60, -20, -50], [12, -20, 15, -10].map { $0 * sign }],
                            styles: [baseStyle, styles[(i + 1) % styles.count], style], stacking: mode))
                        let r = v.rendererForTesting
                        let positive = try area(r, 0), negative = try area(r, 1), crossing = try area(r, 2)
                        for interval in 0..<3 {
                            for step in 1..<23 {
                                let x = r.screenPoint(x: Double(interval) + Double(step) / 23, y: 0, yAxisIndex: 0).x
                                let p = try top(positive, x: x), n = try top(negative, x: x)
                                XCTAssertFalse(crossing.contains(CGPoint(x: x, y: p.y + 0.01)))
                                XCTAssertFalse(crossing.contains(CGPoint(x: x, y: n.y - 0.01)))
                                let positiveLobe = crossing.contains(CGPoint(x: x, y: p.y - 0.01))
                                let negativeLobe = crossing.contains(CGPoint(x: x, y: n.y + 0.01))
                                XCTAssertNotEqual(positiveLobe, negativeLobe, "One sign lobe at every nonzero interior probe: \(baseStyle), \(style), \(sign), \(mode), \(interval), \(step)")
                            }
                        }
                        let zeroY = r.screenPoint(x: 0, y: 0, yAxisIndex: 0).y
                        for edge in edges(try stroke(r, 2)) {
                            XCTAssertFalse((edge.start.y < zeroY && edge.end.y > zeroY) || (edge.start.y > zeroY && edge.end.y < zeroY), "Stroke must move between sign baselines")
                        }
                        XCTAssertEqual(moves(try stroke(r, 2)).count, 4)
                        for index in 0..<4 {
                            let datum = try XCTUnwrap(r.datum(series: 2, category: index))
                            XCTAssertEqual(datum.rawValue, r.currentModel!.series[2].data[index])
                            let hit = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: 2, index: index)) as? LineHitTarget)
                            XCTAssertEqual(hit.seriesIndex, 2); XCTAssertEqual(hit.index, index)
                        }
                        count += 1
                    }
                }
            }
        }
        XCTAssertEqual(count, 150)
    }

    func testSmoothCrossingUsesContributionRootInsteadOfCumulativeOrLinearRoot() throws {
        let v = chart(model([[40, 40, 40], [-30, -30, -30], [10, -30, -40]], styles: [.straight, .straight, .smooth]))
        let r = v.rendererForTesting, starts = moves(try stroke(r, 2))
        XCTAssertEqual(starts.count, 2)
        // Independent reference polynomial: contribution Hermite tangents -40 and -25.
        var lo = 0.0, hi = 1.0
        for _ in 0..<60 {
            let t = (lo + hi) / 2
            if 10 - 40 * t - 15 * t * t + 15 * t * t * t > 0 { lo = t } else { hi = t }
        }
        let expected = r.screenPoint(x: (lo + hi) / 2, y: -30, yAxisIndex: 0)
        XCTAssertEqual(starts[1].x, expected.x, accuracy: 1e-7)
        XCTAssertEqual(starts[1].y, expected.y, accuracy: 1e-7)
        XCTAssertGreaterThan(abs(starts[1].x - r.screenPoint(x: 0.25, y: 0, yAxisIndex: 0).x), 0.1)
    }

    func testZeroSamplesRetainPositiveChainAnchorsForEveryConnectionStyle() throws {
        for style in LineConnectionStyle.allCases {
            for data in [[0.0, -10, 0], [-10, 0, -10], [10, 0, -10], [0, 0, -10]] {
                let v = chart(model([[40, 40, 40], [-30, -30, -30], data], styles: [.stepBefore, .stepAfter, style]))
                let r = v.rendererForTesting, path = try stroke(r, 2)
                let vertices = edges(path).flatMap { [$0.start, $0.end] } + moves(path)
                for i in 0..<3 {
                    let p = r.testScreenPoint(series: 2, index: i)
                    XCTAssertTrue(vertices.contains { abs($0.x - p.x) < 1e-7 && abs($0.y - p.y) < 1e-7 })
                    let datum = try XCTUnwrap(r.datum(series: 2, category: i))
                    XCTAssertEqual(datum.rawValue, data[i])
                    XCTAssertEqual(datum.stackBase, data[i] >= 0 ? 40 : -30)
                }
                for e in edges(try area(r, 2)) {
                    XCTAssertTrue(([e.start, e.end] + e.controls).allSatisfy { $0.x.isFinite && $0.y.isFinite })
                }
            }
        }
        // An off-screen endpoint must not suffer cancellation and invert a zero-width cut.
        typealias Edge = LineStackedAreaGeometry.Edge
        let x0: CGFloat = -1e10, x1: CGFloat = 0.1
        let thickness = [Edge(start: .init(x: x0, y: 10), end: .init(x: x1, y: 0), controls: nil)]
        let positive = [Edge(start: .init(x: x0, y: -40), end: .init(x: x1, y: -40), controls: nil),
                        Edge(start: .init(x: x1, y: -40), end: .init(x: x1, y: -60), controls: nil)]
        let negative = [Edge(start: .init(x: x0, y: 30), end: .init(x: x1, y: 30), controls: nil)]
        let pieces = try XCTUnwrap(LineStackedAreaTransitions.split(thickness: thickness, positive: positive,
                                                                  negative: negative, startsPositive: false))
        XCTAssertEqual(pieces[1].top.last?.end.x, x1)
        XCTAssertEqual(pieces[1].top.last?.end.y, -60)
    }

    func testGapPolicyPreservesSourceBreakWhileUpperBridgesAndSplits() throws {
        var m = model([[40, 40, 40], [-30, -30, -30], [10, .nan, -10]],
                      styles: [.smooth, .stepCenter, .smooth], connects: [false, false, true])
        let v = chart(m); let r = v.rendererForTesting
        XCTAssertEqual(r.renderedIndices[2], [[0, 2]])
        XCTAssertEqual(moves(try stroke(r, 2)).count, 2)
        XCTAssertNil(r.datum(series: 2, category: 1)?.rawValue)
        m.series[2].connectNulls = false
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.renderedIndices[2], [[0], [2]])
        XCTAssertFalse(try area(r, 2).contains(r.screenPoint(x: 0.25, y: 42, yAxisIndex: 0)))
        m.series[2].connectNulls = true; m.series[0].data[1] = .nan
        v.update(model: m); v.layoutIfNeeded()
        let fallback = try area(r, 2)
        let compatible = chart(m, mode: .independent)
        XCTAssertNotEqual(fallback, try area(compatible.rendererForTesting, 2))
        XCTAssertEqual(moves(try stroke(r, 2)).count, 2)
        XCTAssertFalse(try area(r, 0).contains(r.screenPoint(x: 0.5, y: 20)))
        // The intervening negative series has an original point at index 1. Its cached
        // positive base there is 0 (the positive source is missing), so the bridge at .5
        // is 20 and the crossing layer contributes 5. No new business point is inserted.
        XCTAssertTrue(fallback.contains(r.screenPoint(x: 0.5, y: 22)))
        XCTAssertTrue(fallback.contains(r.screenPoint(x: 1.5, y: -32)))
    }

    func testDynamicVisibilityAxesAndModeUpdatesRebuildSplitContours() throws {
        var m = model([[40, 40, 40], [-30, -30, -30], [10, -10, 10]], styles: [.smooth, .stepAfter, .smooth])
        let v = chart(m); let r = v.rendererForTesting
        let split = try stroke(r, 2)
        v.showCategoryRange(0..<2); v.layoutIfNeeded(); let domain = r.currentViewport.xDomain
        m.series[0].isVisible = false
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.currentViewport.xDomain, domain)
        XCTAssertEqual(r.datum(series: 2, category: 0)?.stackBase, 0)
        m.series[0].isVisible = true
        v.update(model: m, viewportPolicy: .reset); v.layoutIfNeeded()
        XCTAssertEqual(try stroke(r, 2), split)
        var theme = r.currentTheme!; theme.stackedAreaBoundaryMode = .independent
        v.update(model: m, theme: theme); v.layoutIfNeeded()
        XCTAssertEqual(moves(try stroke(r, 2)).count, 1)
        theme.stackedAreaBoundaryMode = .followBaseline
        m.secondaryYAxis = .init(kind: .value); m.series[2].yAxisIndex = 1
        v.update(model: m, theme: theme); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 2, category: 0)?.stackBase, 0)
        XCTAssertEqual(r.datum(series: 2, category: 1)?.stackBase, 0)
        XCTAssertEqual(moves(try stroke(r, 2)).count, 3)
        m.series[2].yAxisIndex = 0; m.series[2].stackID = "separate"
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 2, category: 1)?.stackBase, 0)
        m.series[2].stackID = nil; m.series[2].data = [10, 10, 10]
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(moves(try stroke(r, 2)).count, 1)
        m.stacking = .percent; m.series[2].data = [10, -10, 10]
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.percentBoundarySeries, [0, 1, 2])
        XCTAssertGreaterThan(moves(try stroke(r, 2)).count, 1)
        let percent = try area(r, 2)
        theme.stackedAreaBoundaryMode = .independent
        v.update(model: m, theme: theme); v.layoutIfNeeded()
        XCTAssertNotEqual(try area(r, 2), percent)
    }

    func testDemoCombinedAndOCUseTheSameSplitGeometry() throws {
        var expected: CGPath?
        for kind: CartesianDemoKind in [.line, .combined] {
            var state = CartesianDemoState(kind: kind); state.query = "跨零"; state.crossingStackedAreaPreset()
            XCTAssertEqual(state.query, "跨零"); XCTAssertEqual(state.model.maxPointCount, 5)
            XCTAssertEqual(state.selectedSeries, 2); XCTAssertEqual(state.builtTheme.stackedAreaBoundaryMode, .followBaseline)
            if kind == .line {
                let line = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
                line.configure(model: state.model, theme: state.builtTheme); line.layoutIfNeeded()
                expected = try area(line.rendererForTesting, 2)
                XCTAssertEqual(moves(try stroke(line.rendererForTesting, 2)).count, 5)
            } else {
                let combined = HYMChartView<CombinedChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
                combined.configure(model: state.model, theme: state.builtTheme); combined.layoutIfNeeded()
                XCTAssertEqual(try area(combined.rendererForTesting.lines, 2), expected)
                XCTAssertEqual(moves(try stroke(combined.rendererForTesting.lines, 2)).count, 5)
            }
        }
        let source = HYMCartesianModel(); source.stacking = .normal
        source.series = [[40.0, 40, 40], [-30, -30, -30], [10, -10, 10]].enumerated().map { i, data in
            let s = HYMCartesianSeries(); s.identifier = "s\(i)"; s.data = data.map(NSNumber.init(value:)); s.kind = .area
            return s
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: .init(x: 0, y: 0, width: 640, height: 360))
        bridge.stackedAreaFollowsBaseline = true
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let oc = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertEqual(moves(try stroke(oc.rendererForTesting, 2)).count, 3)
        bridge.stackedAreaFollowsBaseline = false
        try bridge.update(model: source, preserveViewport: true); bridge.chartView.layoutIfNeeded()
        XCTAssertEqual(moves(try stroke(oc.rendererForTesting, 2)).count, 1)
    }
}
