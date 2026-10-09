import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class StackedAreaGapBoundaryTests: XCTestCase {
    private func chart(_ data: [[Double]], styles: [LineConnectionStyle] = [.smooth, .straight],
                       mode: StackConfig = .normal) -> HYMChartView<LineChartRenderer> {
        let colors: [UIColor] = [.blue, .orange, .green, .purple]
        let series = data.enumerated().map { i, values in
            var style = CartesianSeriesStyle(); style.showsArea = true; style.showsPoints = false
            style.lineConnectionStyle = styles[i % styles.count]
            style.areaGradientColors = [colors[i].withAlphaComponent(0.6)]
            return CartesianSeriesElement(name: "S\(i)", data: values, color: colors[i],
                connectNulls: i > 0, id: "s\(i)", style: style)
        }
        let view = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
        var theme = CartesianChartTheme(); theme.stackedAreaBoundaryMode = .followBaseline
        view.configure(model: .init(series: series, stacking: mode), theme: theme)
        view.layoutIfNeeded(); return view
    }

    private func area(_ view: HYMChartView<LineChartRenderer>, _ index: Int) throws -> CGPath {
        let gradients = (view.rendererForTesting.seriesLayer.sublayers ?? []).compactMap { $0 as? CAGradientLayer }
        return try XCTUnwrap((gradients[index].mask as? CAShapeLayer)?.path)
    }

    private func attach(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat(); format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { c in
            UIColor.white.setFill(); c.fill(view.bounds); view.layer.render(in: c.cgContext)
        }
        let attachment = XCTAttachment(image: image); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testLongUpperConnectionRetainsBothContinuousLowerPieces() throws {
        let view = chart([[10, 90, .nan, 10, 70], [2, .nan, .nan, .nan, 2]])
        let r = view.rendererForTesting, upper = try area(view, 1), lower = try area(view, 0)
        attach(view, "native-gap-boundary")
        // The source really exists on 0...1 and 3...4. Only 1...3 is a gap bridge.
        for (x, baseline) in [(0.5, 50.0), (3.5, 40.0), (2.0, 50.0)] {
            XCTAssertTrue(upper.contains(r.screenPoint(x: x, y: baseline + 1)))
            XCTAssertFalse(upper.contains(r.screenPoint(x: x, y: baseline - 1)))
        }
        XCTAssertFalse(lower.contains(r.screenPoint(x: 2, y: 25)))
        XCTAssertEqual(r.renderedIndices[0], [[0, 1], [3, 4]])
        XCTAssertEqual(r.renderedIndices[1], [[0, 4]])
        XCTAssertTrue(r.currentModel!.series[0].data[2].isNaN)
        XCTAssertTrue(r.currentModel!.series[1].data[2].isNaN)
        XCTAssertEqual(r.datum(series: 1, category: 4)?.drawValue, 72)
    }

    func testUnresolvedBridgeKeepsSmoothOwnThicknessInsteadOfInvertingIt() throws {
        let view = chart([[90, 10, .nan, 70], [2, 2, .nan, 2]], styles: [.straight, .smooth])
        let r = view.rendererForTesting, upper = try area(view, 1)
        // The cumulative spline turns at 12, while the base bridge rises linearly 10...70.
        // At the midpoint own thickness must remain 2 above the interpolated baseline 40.
        XCTAssertTrue(upper.contains(r.screenPoint(x: 2, y: 41)))
        XCTAssertFalse(upper.contains(r.screenPoint(x: 2, y: 39)))
    }

    private struct Edge: Equatable {
        let start: CGPoint, end: CGPoint
        let controls: [CGPoint]
        var reversed: Edge { .init(start: end, end: start, controls: controls.reversed()) }
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
        var result: [Edge] = [], current = CGPoint.zero
        path.applyWithBlock { p in
            let e = p.pointee
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

    func testGapPiecesRetainExactCurvesAcrossStylesSignsModesAndHigherLayers() throws {
        var count = 0
        for lowerStyle in LineConnectionStyle.allCases {
            for upperStyle in LineConnectionStyle.allCases {
                for sign in [1.0, -1.0] {
                    for mode: StackConfig in [.normal, .percentFixed(max: 200), .grouped(groupCount: 1)] {
                        let values = [10.0, 90, 20, .nan, 70, 15, 50].map { $0 * sign }
                        let view = chart([values, [4, .nan, .nan, .nan, .nan, .nan, 4].map { $0 * sign },
                                          [3, .nan, .nan, .nan, .nan, .nan, 3].map { $0 * sign }],
                                         styles: [lowerStyle, upperStyle], mode: mode)
                        let r = view.rendererForTesting, paths = try (0..<3).map { try area(view, $0) }
                        let factor = mode == .percentFixed(max: 200) ? 0.5 : 1.0
                        let dy = r.screenPoint(x: 0, y: 4 * sign * factor).y - r.screenPoint(x: 0, y: 0).y
                        let top = edges(paths[0]).filter { $0.end.x > $0.start.x }
                        let bottom = edges(paths[1]).filter { $0.end.x < $0.start.x }
                        XCTAssertFalse(top.isEmpty)
                        for edge in top {
                            XCTAssertTrue(bottom.contains(edge.reversed), "Lost exact source curve: \(lowerStyle)/\(upperStyle)")
                            for t: CGFloat in [0.17, 0.43, 0.81] {
                                let p = edge.value(t)
                                let first = CGPoint(x: p.x, y: p.y + dy / 2)
                                let second = CGPoint(x: p.x, y: p.y + dy * 1.375)
                                XCTAssertTrue(paths[1].contains(first)); XCTAssertFalse(paths[0].contains(first))
                                XCTAssertTrue(paths[2].contains(second)); XCTAssertFalse(paths[1].contains(second))
                            }
                        }
                        // Only the actual source gap 2...4 gets the straight 20...70 base.
                        XCTAssertTrue(paths[1].contains(r.screenPoint(x: 3, y: 47 * sign * factor)))
                        XCTAssertTrue(paths[2].contains(r.screenPoint(x: 3, y: 50 * sign * factor)))
                        XCTAssertFalse(paths[0].contains(r.screenPoint(x: 3, y: 20 * sign * factor)))
                        XCTAssertEqual(r.renderedIndices[1], [[0, 6]])
                        XCTAssertNil(r.datum(series: 1, category: 3)?.rawValue)
                        XCTAssertEqual(r.datum(series: 1, category: 6)?.rawValue, 4 * sign)
                        count += 1
                    }
                }
            }
        }
        XCTAssertEqual(count, 150)
    }

    func testMissingEndpointsDoNotHideInteriorIslandsAndCrossingUsesBothSignBridges() throws {
        let view = chart([Array(repeating: 20, count: 7), [.nan, 30, 50, .nan, 20, 40, .nan],
                          [5, .nan, .nan, .nan, .nan, .nan, 5]], styles: [.straight])
        var m = view.rendererForTesting.currentModel!; m.series[1].connectNulls = false
        view.update(model: m); view.layoutIfNeeded()
        let r = view.rendererForTesting, upper = try area(view, 2)
        XCTAssertTrue(upper.contains(r.screenPoint(x: 1.5, y: 62)))
        XCTAssertTrue(upper.contains(r.screenPoint(x: 4.5, y: 52)))
        XCTAssertFalse(upper.contains(r.screenPoint(x: 1.5, y: 22)))
        let cross = chart([[40, 20, .nan, -20, -40], [8, .nan, .nan, .nan, -8]], styles: [.straight])
        let cr = cross.rendererForTesting, path = try area(cross, 1)
        XCTAssertTrue(path.contains(cr.screenPoint(x: 1.5, y: 16)))
        XCTAssertTrue(path.contains(cr.screenPoint(x: 2.5, y: -16)))
        XCTAssertFalse(path.contains(cr.screenPoint(x: 2, y: 0)))
        XCTAssertEqual(cr.renderedIndices[1], [[0, 4]])
    }

    func testGapPolicyOverridesAndNonfiniteDataKeepTheirOriginalSemantics() throws {
        for missing in [Double.nan, .infinity, -.infinity] {
            let view = chart([[10, 90, missing, 20, 60], [2, .nan, .nan, .nan, 2]])
            let r = view.rendererForTesting
            for (policy, connected): (CartesianGapPolicy, Bool) in [(.breakAll, false), (.connectAll, true),
                (.autoGap(maximumMissingPoints: 0), false), (.autoGap(maximumMissingPoints: 1), true),
                (.autoGapDuration(maximumMissingDuration: 59), false), (.autoGapDuration(maximumMissingDuration: 60), true)] {
                var m = r.currentModel!; m.series[0].gapPolicy = policy
                m.series[0].connectNulls = !connected // Explicit policy takes precedence.
                m.timeAxis = .init(start: Date(timeIntervalSince1970: 0), interval: 60)
                view.update(model: m); view.layoutIfNeeded()
                XCTAssertEqual(r.renderedIndices[0], connected ? [[0, 1, 3, 4]] : [[0, 1], [3, 4]])
                XCTAssertEqual(r.renderedIndices[1], [[0, 4]])
                XCTAssertNil(r.datum(series: 0, category: 2)?.rawValue)
                XCTAssertNil(r.datum(series: 1, category: 2)?.rawValue)
                XCTAssertEqual(r.datum(series: 1, category: 4)?.stackBase, 60)
                let lower = try area(view, 0)
                XCTAssertEqual(lower.contains(r.screenPoint(x: 2, y: 1)), connected)
            }
        }
    }

    private func image(_ layer: CALayer, scale: CGFloat = 2) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(size: .init(width: 640, height: 360), format: format).image { layer.render(in: $0.cgContext) }
    }

    private func alpha(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let c = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            c.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
    }

    func testGapAndSegmentEndStrokesRemainInsideAreaAtAllScales() throws {
        for style in LineConnectionStyle.allCases {
            let view = chart([[10, 90, 20, .nan, 70, 15, 50], [4, .nan, .nan, .nan, .nan, .nan, 4]], styles: [style, .smooth])
            let r = view.rendererForTesting
            var theme = r.currentTheme!; theme.lineWidth = 6
            view.update(theme: theme); view.layoutIfNeeded()
            let strokes = (r.seriesLayer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.filter { $0.fillColor == nil }
            XCTAssertEqual(strokes.count, 2)
            for (s, stroke) in strokes.enumerated() {
                for scale: CGFloat in [1, 2, 3] {
                    let allowed = CAShapeLayer(); allowed.path = try area(view, s)
                    allowed.fillColor = UIColor.black.cgColor; allowed.strokeColor = UIColor.black.cgColor
                    allowed.lineWidth = 2 / scale
                    let coverage = try alpha(image(allowed, scale: scale)), actual = try alpha(image(stroke, scale: scale))
                    XCTAssertTrue(actual.contains { $0 > 16 })
                    XCTAssertEqual(zip(coverage, actual).filter { $0 == 0 && $1 > 16 }.count, 0)
                }
            }
        }
    }

    func testUpdatesRebuildGapGeometryAndCompatibilityModesStayUnchanged() throws {
        let data = [[10.0, 90, .nan, 10, 70], [2, .nan, .nan, .nan, 2]]
        let view = chart(data), r = view.rendererForTesting
        let initialModel = r.currentModel!, initialTheme = r.currentTheme!
        for state in 0..<11 {
            var m = initialModel, theme = initialTheme
            switch state {
            case 1: m.series[0].gapPolicy = .connectAll
            case 2: m.series[1].connectNulls = false
            case 3: m.series[0].isVisible = false
            case 4: m.series[0].stackID = "other"
            case 5: m.secondaryYAxis = .init(kind: .value); m.series[0].yAxisIndex = 1
            case 6: m.stacking = .percent
            case 7: theme.stackedAreaBoundaryMode = .independent
            case 8: m.series = []
            case 9: m.series[0].data = [5, .nan, 20, 80, 10]
            default: break
            }
            view.update(model: m, theme: theme, viewportPolicy: .reset); view.layoutIfNeeded()
            let fresh = chart(data); var noReuse = theme; noReuse.reusesRenderingObjects = false
            fresh.configure(model: m, theme: noReuse); fresh.layoutIfNeeded()
            XCTAssertEqual(image(view.layer).pngData(), image(fresh.layer).pngData(), "state \(state)")
            if state == 6 {
                noReuse.stackedAreaBoundaryMode = .independent
                fresh.update(theme: noReuse); fresh.layoutIfNeeded()
                XCTAssertEqual(image(view.layer).pngData(), image(fresh.layer).pngData())
            }
        }
        view.showCategoryRange(1..<4); view.layoutIfNeeded()
        let domain = r.currentViewport.xDomain
        view.update(model: initialModel, viewportPolicy: .preserve); view.layoutIfNeeded()
        XCTAssertEqual(r.currentViewport.xDomain, domain)
    }

    func testDemoLineCombinedAndOCBridgePreserveSamplesAndMatchingAreas() throws {
        var line = CartesianDemoState(kind: .line), combinedState = CartesianDemoState(kind: .combined)
        line.gapBoundaryStackedAreaPreset(); combinedState.gapBoundaryStackedAreaPreset()
        XCTAssertFalse(line.model.series[0].connectNulls); XCTAssertTrue(line.model.series[1].connectNulls)
        let view = chart([[1, 2], [3, 4]])
        view.configure(model: line.model, theme: line.builtTheme); view.layoutIfNeeded()
        let combined = HYMChartView<CombinedChartRenderer>(frame: view.frame)
        combined.configure(model: combinedState.model, theme: combinedState.builtTheme); combined.layoutIfNeeded()
        func paths(_ layer: CALayer) -> [CGPath] {
            if let gradient = layer as? CAGradientLayer, let path = (gradient.mask as? CAShapeLayer)?.path { return [path] }
            return (layer.sublayers ?? []).flatMap(paths)
        }
        XCTAssertEqual(paths(view.rendererForTesting.rootLayer), paths(combined.rendererForTesting.rootLayer))
        let r = view.rendererForTesting
        let hit = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: 1, index: 6)) as? LineHitTarget)
        XCTAssertEqual(hit.index, 6); XCTAssertEqual(hit.rawValue, 4)
        XCTAssertNil(r.datum(series: 1, category: 3)?.rawValue)
        let source = HYMCartesianModel(); source.stacking = .normal
        source.series = [[10.0, 90, .nan, 10, 70], [2, .nan, .nan, .nan, 2]].enumerated().map { i, data in
            let s = HYMCartesianSeries(); s.data = data.map(NSNumber.init(value:)); s.kind = .area
            s.connectNulls = i == 1; return s
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: view.frame)
        bridge.stackedAreaFollowsBaseline = true; try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let oc = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertTrue(try area(oc, 1).contains(oc.rendererForTesting.screenPoint(x: 0.5, y: 51)))
        bridge.stackedAreaFollowsBaseline = false; try bridge.update(model: source, preserveViewport: true); oc.layoutIfNeeded()
        XCTAssertFalse(try area(oc, 1).contains(oc.rendererForTesting.screenPoint(x: 0.5, y: 51)))
    }
}
