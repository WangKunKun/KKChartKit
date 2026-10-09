import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class PercentStackedAreaTests: XCTestCase {
    private func chart(_ data: [[Double]], styles: [LineConnectionStyle],
                       boundary: StackedAreaBoundaryMode = .followBaseline) -> HYMChartView<LineChartRenderer> {
        let colors: [UIColor] = [.blue, .orange, .green, .purple]
        let series = data.enumerated().map { i, values in
            var style = CartesianSeriesStyle(); style.showsArea = true; style.showsPoints = false
            style.lineConnectionStyle = styles[i % styles.count]
            style.areaGradientColors = [colors[i % colors.count].withAlphaComponent(0.6)]
            return CartesianSeriesElement(name: "S\(i)", data: values, color: colors[i % colors.count], id: "s\(i)", style: style)
        }
        var theme = CartesianChartTheme(); theme.stackedAreaBoundaryMode = boundary
        let view = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
        view.configure(model: .init(series: series, stacking: .percent), theme: theme); view.layoutIfNeeded()
        return view
    }
    private func areas(_ root: CALayer) -> [CGPath] {
        if let g = root as? CAGradientLayer, let p = (g.mask as? CAShapeLayer)?.path { return [p] }
        return (root.sublayers ?? []).flatMap(areas)
    }
    private func attach(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat(); format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { c in
            UIColor.white.setFill(); c.fill(view.bounds); view.layer.render(in: c.cgContext)
        }
        let a = XCTAttachment(image: image); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testMixedPercentThinLayerUsesSharedNormalizationAndKeepsHundredEnvelope() throws {
        let view = chart([[10, 90, 10], [0.1, 0.1, 0.1], [3, 3, 3]], styles: [.smooth, .straight, .stepAfter])
        let r = view.rendererForTesting, paths = areas(r.seriesLayer)
        XCTAssertEqual(r.percentBoundarySeries, [0, 1, 2])
        XCTAssertEqual(paths.count, 3); attach(view, "native-percent-boundary")
        let values = r.currentBaseValues
        // Independent reference for x=.5: first smooth Hermite interval, linear thin layer,
        // and a held step. Normalize all signed magnitudes with one shared denominator.
        let first = values[0][0] + (values[0][1] - values[0][0]) * 0.625
        let thin = (values[1][0] + values[1][1]) / 2, step = values[2][0]
        let total = first + thin + step, mid = (first + thin / 2) / total * 100
        let p = r.screenPoint(x: 0.5, y: mid)
        XCTAssertTrue(paths[1].contains(p)); XCTAssertFalse(paths[0].contains(p)); XCTAssertFalse(paths[2].contains(p))
        XCTAssertTrue(paths[2].contains(r.screenPoint(x: 0.5, y: 99.9)))
        XCTAssertFalse(paths[2].contains(r.screenPoint(x: 0.5, y: 100.1)))
        XCTAssertEqual(r.datum(series: 1, category: 1)?.rawValue, 0.1)
        XCTAssertEqual(r.datum(series: 2, category: 1)!.drawValue, 100, accuracy: 1e-10)
    }

    private struct Edge {
        let start: CGPoint, end: CGPoint
        let controls: [CGPoint]
        func at(_ x: CGFloat) -> CGFloat {
            let t = (x - start.x) / (end.x - start.x)
            var ys = [start.y] + controls.map(\.y) + [end.y]
            while ys.count > 1 { ys = zip(ys, ys.dropFirst()).map { $0 + ($1 - $0) * t } }
            return ys[0]
        }
    }
    private func forward(_ path: CGPath) -> [Edge] {
        var p = CGPoint.zero, result: [Edge] = []
        path.applyWithBlock { ptr in
            let e = ptr.pointee
            switch e.type {
            case .moveToPoint: p = e.points[0]
            case .addLineToPoint:
                if e.points[0].x > p.x { result.append(.init(start: p, end: e.points[0], controls: [])) }
                p = e.points[0]
            case .addCurveToPoint:
                if e.points[2].x > p.x { result.append(.init(start: p, end: e.points[2], controls: [e.points[0], e.points[1]])) }
                p = e.points[2]
            default: break
            }
        }
        return result
    }
    private func interpolation(_ values: [Double], style: LineConnectionStyle, x: Double) -> Double {
        let i = Int(x), t = x - Double(i), a = values[i], b = values[i + 1]
        switch style {
        case .straight: return a + (b - a) * t
        case .stepBefore: return b
        case .stepAfter: return a
        case .stepCenter: return t < 0.5 ? a : b
        case .smooth:
            // Evaluate only the existing raw-share interpolation. This reference does not
            // use the new denominator/control-net normalization or shared area builder.
            let p = UIBezierPath(); p.move(to: .init(x: 0, y: values[0]))
            CartesianGeometry.appendSmoothCurve(to: p, points: values.enumerated().map { .init(x: Double($0), y: $1) })
            return Double(forward(p.cgPath)[i].at(CGFloat(x)))
        }
    }

    func testAllMixedStylesAndSignsMatchRationalReferenceWithoutOverlapsOrEnvelopeOverflow() throws {
        var count = 0
        for a in LineConnectionStyle.allCases {
            for b in LineConnectionStyle.allCases {
                for c in LineConnectionStyle.allCases {
                    for sign in [1.0, -1.0] {
                        let data = [[10.0, 80, 20, 60].map { $0 * sign }, [6, -5, 8, -4], [3, 3, 3, 3].map { $0 * sign }]
                        let styles = [a, b, c], view = chart(data, styles: styles), r = view.rendererForTesting
                        XCTAssertEqual(r.percentBoundarySeries, [0, 1, 2], "\(styles), \(sign)")
                        let paths = areas(r.seriesLayer), tops = paths.map(forward)
                        XCTAssertEqual(paths.count, 3)
                        for interval in 0..<3 {
                            for fraction in [0.11, 0.29, 0.47, 0.63, 0.87] {
                                let x = Double(interval) + fraction
                                let interpolated = (0..<3).map { interpolation(r.currentBaseValues[$0], style: styles[$0], x: x) }
                                let total = interpolated.reduce(0) { $0 + abs($1) }, weights = interpolated.map { $0 / total * 100 }
                                let screenX = r.screenPoint(x: x, y: 0).x
                                var ys = [r.screenPoint(x: x, y: 0).y]
                                for s in 0..<3 {
                                    let base = weights.prefix(s).filter { ($0 >= 0) == (weights[s] >= 0) }.reduce(0, +)
                                    let edge = try XCTUnwrap(tops[s].first { $0.start.x <= screenX && $0.end.x >= screenX })
                                    let y = edge.at(screenX); ys.append(y)
                                    XCTAssertEqual(y, r.screenPoint(x: x, y: base + weights[s]).y, accuracy: 0.051)
                                    let mid = r.screenPoint(x: x, y: base + weights[s] / 2)
                                    let thickness = abs(r.screenPoint(x: x, y: weights[s]).y - r.screenPoint(x: x, y: 0).y)
                                    if thickness > 0.21 {
                                        XCTAssertTrue(paths[s].contains(mid))
                                        for other in 0..<3 where other != s { XCTAssertFalse(paths[other].contains(mid)) }
                                    }
                                }
                                let span = abs(r.screenPoint(x: x, y: 100).y - r.screenPoint(x: x, y: 0).y)
                                XCTAssertEqual(ys.max()! - ys.min()!, span, accuracy: 1e-6)
                            }
                        }
                        for s in 0..<3 {
                            XCTAssertEqual(r.renderedIndices[s], [[0, 1, 2, 3]])
                            for i in 0..<4 { XCTAssertEqual(r.datum(series: s, category: i)?.rawValue, data[s][i]) }
                        }
                        count += 1
                    }
                }
            }
        }
        XCTAssertEqual(count, 250)
    }

    private func image(_ layer: CALayer, scale: CGFloat = 2) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(size: .init(width: 640, height: 360), format: format).image { layer.render(in: $0.cgContext) }
    }
    func testAbsoluteDenominatorAndAtomicFallbacksPreserveCurrentSemantics() throws {
        let view = chart([[60, 60, 60], [-40, -40, -40]], styles: [.smooth, .stepCenter])
        let r = view.rendererForTesting
        XCTAssertEqual(r.percentBoundarySeries, [0, 1])
        XCTAssertEqual(r.datum(series: 0, category: 1)?.drawValue, 60)
        XCTAssertEqual(r.datum(series: 1, category: 1)?.drawValue, -40)
        let original = r.currentModel!, theme = r.currentTheme!
        for state in 0..<4 {
            var m = original
            switch state {
            case 0: m.series[1].style.showsArea = false
            case 1: m.series[1].data[1] = .nan
            case 2: m.series[0].data[1] = 0; m.series[1].data[1] = 0
            default:
                m.series[0].data = [10, -10, 10]; m.series[1].data = [20, -20, 20]
                m.series[0].style.lineConnectionStyle = .straight; m.series[1].style.lineConnectionStyle = .straight
            }
            view.update(model: m, theme: theme); view.layoutIfNeeded()
            XCTAssertTrue(r.percentBoundarySeries.isEmpty, "state \(state)")
            let compatible = chart([[1, 1, 1], [2, 2, 2]], styles: [.straight], boundary: .independent)
            var t = theme; t.stackedAreaBoundaryMode = .independent
            compatible.configure(model: m, theme: t); compatible.layoutIfNeeded()
            XCTAssertEqual(image(view.layer).pngData(), image(compatible.layer).pngData())
        }
    }

    func testMatchingGapRunsConnectAndBreakWithoutCreatingSamples() throws {
        let view = chart([[10, 30, .nan, 20, 60], [2, 3, .nan, 4, 5]], styles: [.smooth, .stepCenter])
        let r = view.rendererForTesting
        for connect in [false, true] {
            var m = r.currentModel!; m.series[0].connectNulls = connect; m.series[1].connectNulls = connect
            view.update(model: m); view.layoutIfNeeded()
            XCTAssertEqual(r.percentBoundarySeries, [0, 1])
            XCTAssertEqual(r.renderedIndices[0], connect ? [[0, 1, 3, 4]] : [[0, 1], [3, 4]])
            XCTAssertNil(r.datum(series: 0, category: 2)?.rawValue)
            XCTAssertNil(r.datum(series: 1, category: 2)?.rawValue)
            let paths = areas(r.seriesLayer)
            XCTAssertEqual(paths.contains { $0.contains(r.screenPoint(x: 2, y: 50)) }, connect)
        }
        var m = r.currentModel!; m.series[0].gapPolicy = .breakAll
        view.update(model: m); view.layoutIfNeeded()
        XCTAssertTrue(r.percentBoundarySeries.isEmpty)
    }

    func testVisibilityStackAxisIsolationUpdatesAndViewportMatchFreshGeometry() throws {
        let data = [[10.0, 90, 10], [2, 2, 2], [3, 3, 3]], styles: [LineConnectionStyle] = [.smooth, .straight, .stepAfter]
        let view = chart(data, styles: styles), r = view.rendererForTesting
        let original = r.currentModel!, initialTheme = r.currentTheme!
        for state in 0..<11 {
            var m = original, t = initialTheme
            switch state {
            case 1: m.series[2].isVisible = false
            case 2: m.series[2].stackID = "other"
            case 3: m.secondaryYAxis = .init(kind: .value); m.series[2].yAxisIndex = 1
            case 4: m.series[2].participatesInStack = false
            case 5: m.series[0].data = [20, -80, 30]
            case 6: t.stackedAreaBoundaryMode = .independent
            case 7: m.stacking = .normal
            case 8: m.series = []
            case 9: m.series[1].colorZones = .init(axis: .x, zones: [.init(upperBound: 1, color: .purple), .init(color: .orange)])
            default: break
            }
            view.update(model: m, theme: t, viewportPolicy: .reset); view.layoutIfNeeded()
            let fresh = chart(data, styles: styles); var nt = t; nt.reusesRenderingObjects = false
            fresh.configure(model: m, theme: nt); fresh.layoutIfNeeded()
            XCTAssertEqual(image(view.layer).pngData(), image(fresh.layer).pngData(), "state \(state)")
            if state == 1 { XCTAssertEqual(r.datum(series: 1, category: 1)!.drawValue, 100, accuracy: 1e-9) }
            if state == 2 || state == 3 { XCTAssertEqual(r.datum(series: 2, category: 1)!.drawValue, 100, accuracy: 1e-9) }
            if state == 4 { XCTAssertEqual(r.datum(series: 2, category: 1)?.drawValue, 3); XCTAssertFalse(r.percentBoundarySeries.contains(2)) }
        }
        view.showCategoryRange(0..<2); view.layoutIfNeeded(); let domain = r.currentViewport.xDomain
        view.update(model: original, viewportPolicy: .preserve); view.layoutIfNeeded()
        XCTAssertEqual(r.currentViewport.xDomain, domain)
        XCTAssertEqual(r.percentBoundarySeries, [0, 1, 2])
    }

    private func alpha(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage); var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let c = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            c.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
    }
    func testPercentStrokeAtCurveStepAndSignJoinsStaysInsideAreaAtAllScales() throws {
        for style in LineConnectionStyle.allCases {
            let view = chart([[10, 90, 10], [2, -3, 2], [3, 3, 3]], styles: [.smooth, style, .straight])
            let r = view.rendererForTesting; var t = r.currentTheme!; t.lineWidth = 6
            view.update(theme: t); view.layoutIfNeeded(); XCTAssertEqual(r.percentBoundarySeries.count, 3)
            let paths = areas(r.seriesLayer)
            let strokes = (r.seriesLayer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.filter { $0.fillColor == nil }
            XCTAssertEqual(strokes.count, 3)
            for (s, stroke) in strokes.enumerated() {
                for scale: CGFloat in [1, 2, 3] {
                    let allowed = CAShapeLayer(); allowed.path = paths[s]
                    allowed.fillColor = UIColor.black.cgColor; allowed.strokeColor = UIColor.black.cgColor; allowed.lineWidth = 2 / scale
                    let expected = try alpha(image(allowed, scale: scale)), actual = try alpha(image(stroke, scale: scale))
                    XCTAssertTrue(actual.contains { $0 > 16 })
                    XCTAssertEqual(zip(expected, actual).filter { $0 == 0 && $1 > 16 }.count, 0)
                }
            }
        }
    }

    func testNormalizerRejectsSingularOrUnboundedWorkAndKeepsCertifiedAccuracy() {
        typealias Edge = LineStackedAreaGeometry.Edge
        let edge = Edge(start: .init(x: 0, y: 10), end: .init(x: 1, y: 90), controls: (.init(x: 1.0/3, y: 20), .init(x: 2.0/3, y: 90)))
        let constant = Edge(start: .init(x: 0, y: 5), end: .init(x: 1, y: 5), controls: nil)
        var output = [[LinePercentAreaNormalizer.Slice](), []], budget = LinePercentAreaNormalizer.maximumPieces
        XCTAssertTrue(LinePercentAreaNormalizer.append([edge, constant], pixelsPerPercent: 25, budget: &budget, into: &output))
        XCTAssertGreaterThan(output[0].count, 1)
        for cell in output[0] {
            for fraction: CGFloat in [0.07, 0.23, 0.41, 0.67, 0.93] {
                let x = cell.top.start.x + (cell.top.end.x - cell.top.start.x) * fraction
                let raw = edgeValue(edge, at: x), expected = raw / (raw + 5) * 100
                XCTAssertEqual(edgeValue(cell.top, at: x), expected, accuracy: 0.05 / 25)
            }
        }
        budget = 0; output = [[], []]
        XCTAssertFalse(LinePercentAreaNormalizer.append([constant, constant], pixelsPerPercent: 1, budget: &budget, into: &output))
        let zero = Edge(start: .zero, end: .init(x: 1, y: 0), controls: nil)
        budget = 100
        XCTAssertFalse(LinePercentAreaNormalizer.append([zero, zero], pixelsPerPercent: 1, budget: &budget, into: &output))
    }
    private func edgeValue(_ edge: LineStackedAreaGeometry.Edge, at x: CGFloat) -> CGFloat {
        Edge(start: edge.start, end: edge.end, controls: edge.controls.map { [$0.0, $0.1] } ?? []).at(x)
    }

    func testDemoLineCombinedAndOCUseTheSamePercentGeometryAndRawHits() throws {
        var line = CartesianDemoState(kind: .line), combinedState = CartesianDemoState(kind: .combined)
        line.percentStackedAreaPreset(); combinedState.percentStackedAreaPreset()
        let view = chart([[1, 2]], styles: [.straight])
        view.configure(model: line.model, theme: line.builtTheme); view.layoutIfNeeded()
        let combined = HYMChartView<CombinedChartRenderer>(frame: view.frame)
        combined.configure(model: combinedState.model, theme: combinedState.builtTheme); combined.layoutIfNeeded()
        let r = view.rendererForTesting
        XCTAssertEqual(r.percentBoundarySeries, [0, 1, 2])
        XCTAssertEqual(areas(r.rootLayer), areas(combined.rendererForTesting.rootLayer))
        let hit = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: 1, index: 0)) as? LineHitTarget)
        XCTAssertEqual(hit.index, 0); XCTAssertEqual(r.datum(series: 1, category: 0)?.rawValue, 1)
        let source = HYMCartesianModel(); source.stacking = .percent
        source.series = [[10.0, 90, 10], [2, 2, 2]].map { data in
            let s = HYMCartesianSeries(); s.data = data.map(NSNumber.init(value:)); s.kind = .areaspline; return s
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: view.frame)
        bridge.stackedAreaFollowsBaseline = true; try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let oc = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertEqual(oc.rendererForTesting.percentBoundarySeries, [0, 1])
        XCTAssertEqual(oc.rendererForTesting.datum(series: 1, category: 1)?.rawValue, 2)
        bridge.stackedAreaFollowsBaseline = false; try bridge.update(model: source, preserveViewport: true); oc.layoutIfNeeded()
        XCTAssertTrue(oc.rendererForTesting.percentBoundarySeries.isEmpty)
    }
}
